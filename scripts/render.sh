#!/usr/bin/env bash
# Render an OpenSCAD file to a PNG for quick visual inspection.
#
# Usage:
#   ./render.sh <file.scad> [output.png] [-- extra openscad args...]
#
# If output.png is omitted, it defaults to <file>.png next to the
# input file. Any args after a literal "--" are passed through to
# openscad as-is (e.g. -D "num_holes=2").

set -euo pipefail

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <file.scad> [output.png] [-- extra openscad args...]" >&2
    exit 1
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

scad_file="$1"
shift

if [[ ! -f "$scad_file" ]]; then
    echo "error: no such file: $scad_file" >&2
    exit 1
fi

out_file="${scad_file%.scad}.png"
if [[ $# -gt 0 && "$1" != "--" ]]; then
    out_file="$1"
    shift
fi

if [[ $# -gt 0 && "$1" == "--" ]]; then
    shift
fi

"$openscad_bin" --render "${backend_flag[@]}" --imgsize=1000,1000 --autocenter --viewall \
    -o "$out_file" "$scad_file" "$@"

echo "Rendered: $out_file"
