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

if ! command -v openscad >/dev/null 2>&1; then
    echo "error: openscad not found on PATH" >&2
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

openscad --render --imgsize=1000,1000 --autocenter --viewall \
    -o "$out_file" "$scad_file" "$@"

echo "Rendered: $out_file"
