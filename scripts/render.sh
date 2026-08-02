#!/usr/bin/env bash
# Render every root .scad file that has a matching STL in stl/ (the
# box-split-*, backpanel-split-*, and trim pieces), overwriting each STL
# in place. What's in stl/ is the source of truth for what gets
# rendered -- add or remove a piece there to change what this covers.
# Then renders all those STLs together, laid out in a grid, into
# images/pieces.png -- the README pulls this in as the printable-pieces
# overview.
#
# Usage:
#   ./render.sh [-- extra openscad args...]

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
stl_dir="$repo_root/stl"

if [[ $# -gt 0 && "$1" == "--" ]]; then
    shift
fi

# Prefer the nightly build's Manifold backend -- 10-1000x faster than the
# CGAL-only stable release on this project's chained-boolean-heavy parts
# (see CLAUDE.md "Rendering / verification"). Falls back to whatever
# "openscad" resolves to on PATH, without --backend (older builds don't
# have that flag and would just error on it).
nightly="/c/Program Files/OpenSCAD (Nightly)/openscad.com"
backend_flag=()
if [[ -x "$nightly" ]]; then
    openscad_bin="$nightly"
    backend_flag=(--backend Manifold)
elif command -v openscad >/dev/null 2>&1; then
    openscad_bin="openscad"
    echo "warning: nightly build not found at '$nightly' -- falling back to" \
         "'openscad' on PATH (likely the slow CGAL-only backend)" >&2
else
    echo "error: no OpenSCAD found (checked '$nightly' and PATH)" >&2
    exit 1
fi

shopt -s nullglob
stl_files=("$stl_dir"/*.stl)
shopt -u nullglob

if [[ ${#stl_files[@]} -eq 0 ]]; then
    echo "error: no STLs found in $stl_dir" >&2
    exit 1
fi

rendered=0
for stl_file in "${stl_files[@]}"; do
    name="$(basename "$stl_file" .stl)"
    scad_file="$repo_root/$name.scad"
    if [[ ! -f "$scad_file" ]]; then
        echo "warning: no matching $name.scad in repo root -- skipping $stl_file" >&2
        continue
    fi
    echo "=== $name ==="
    "$openscad_bin" --render "${backend_flag[@]}" -o "$stl_file" "$scad_file" "$@"
    rendered=$((rendered + 1))
done

echo "Rendered $rendered STL(s) into $stl_dir"

# ---------- Combined overview image ----------
# Lays every STL out in a grid (translate only -- no rotation, so each
# piece keeps whatever orientation it was exported in) and renders one
# PNG of all of them together. Spacing (500mm) just needs to clear the
# largest single piece (~320mm, the outer box segments) in every
# direction; it doesn't need to track each piece's actual bounding box.
images_dir="$repo_root/images"
mkdir -p "$images_dir"

combo_scad="$(mktemp --suffix=.scad)"
trap 'rm -f "$combo_scad"' EXIT

cols=3
spacing=500
i=0
for stl_file in "${stl_files[@]}"; do
    col=$((i % cols))
    row=$((i / cols))
    # openscad.com is a native Windows binary: MSYS auto-translates POSIX
    # paths passed as argv, but not ones embedded in a file it reads --
    # cygpath converts this one before it goes into the import() string.
    # -m (not -w) keeps forward slashes, which sidesteps backslash-escape
    # parsing in the OpenSCAD string literal.
    win_path="$(cygpath -m "$stl_file")"
    printf 'translate([%d, %d, 0]) import("%s");\n' \
        "$((col * spacing))" "$((-row * spacing))" "$win_path" >>"$combo_scad"
    i=$((i + 1))
done

"$openscad_bin" --render "${backend_flag[@]}" --imgsize=2000,1500 --autocenter --viewall \
    -o "$images_dir/pieces.png" "$combo_scad" "$@"

echo "Rendered overview image: $images_dir/pieces.png"
