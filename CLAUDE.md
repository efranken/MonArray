# monarray

OpenSCAD models for an arched, multi-driver speaker/BMR enclosure and its
trim piece. Fusion 360 was the original source (see `ExportedParameters.csv`
references in comments); this repo re-derives the geometry parametrically.

## Files

- `params.scad` — every parameter for both parts, in three blocks:
  Shared (bore/boss geometry used by both), Box-only, Trim-only. Both
  `box.scad` and `trim.scad` do `include <params.scad>` (not `use`, since
  `include` also pulls in plain variables, not just modules/functions).
  **When adding a parameter, put it here, in the right block — never
  hardcode a value directly in box.scad/trim.scad.**
- `box.scad` — the arched hollow bar: concave-arc profile, extruded,
  shelled hollow, with BMR cutouts on the arc face, an open back (no rear
  wall) with a perimeter lip, M3 heat-set insert holes around that rim,
  optional internal dividers, and mounting bosses on the arc-side facets.
- `trim.scad` — a stepped cap that plugs into a BMR bore from outside and
  clips onto the box's mounting bosses.

## Coordinate convention (box.scad)

Inside `arched_hole_bar()`'s difference/union block, before the final
`translate([0,height/2,0]) rotate([90,0,0])` that orients the finished
part, the working frame is:
- `x` — box length (chord direction), `-Xe..Xe`
- `y` — depth, `0` at the flat rear face (the wall closest to a mounting
  surface) increasing toward the arc face (`bar_depth..bar_depth+arc_depth`)
- `z` — the "height" extrusion axis, `0..height`, which becomes vertical
  in the final part

`Xi = Xe - wall_width` is the cavity half-length (end walls inset).
`d_in = R + wall_width` is the tangency radius for the faceted cavity
wall behind the arc holes.

## Known OpenSCAD gotchas that bit us here

- `rotate([90,0,0])` sends local `+z` to `-y`; `rotate([-90,0,0])` sends
  it to `+y`. Getting this backwards silently drops a cutter into open
  space instead of through material — worth double-checking by hand when
  adding a new radial/axial hole.
- Subtracting a cutter whose face is exactly coincident with the target
  surface (e.g. cutting at `y=0` when the profile's own face is at
  `y=0`) risks a degenerate/non-manifold result. The fix used throughout
  this file: give cutters a small overhang (extend ~1mm past the surface
  being cut) — see `shell_cavity_cut()` vs the flush `shell_cavity()`,
  and the entry overhang in `m3_insert_hole()` / `boss_hole_cutter()`.
- A cavity/mask used for subtraction (needs the overhang epsilon) is not
  the same as one used to *clip additive geometry* (e.g. `dividers()`
  intersecting against the cavity shape) — the clipping version must
  stay flush or the additive feature will protrude past the surface it's
  supposed to be flush with. This is why `shell_cavity()` (flush) and
  `shell_cavity_cut()` (epsilon-extended) are separate modules.
- Building a stepped-diameter cutter as a union of distinct-radius
  `cylinder()`s is fine and used deliberately (see `boss_hole_cutter()`
  comment); but a union of two cylinders fed into `rotate_extrude()`
  leaves an internal seam that can silently corrupt STL export even
  though F5 preview looks fine — that's why `stepped_cutter()` uses one
  continuous polygon revolved once, not two revolved unions.
- F5 preview can visually fail to show a cut correctly in a deeply
  nested boolean tree (this file has several), even when the underlying
  CSG is correct. If a hole/feature looks wrong, verify with F6 (render)
  before assuming the geometry is broken.

## Rendering / verification

`openscad.com` (the CLI variant) lives at
`C:\Program Files\OpenSCAD\openscad.com`. A full STL export of `box.scad`
is slow (arc profile + 10 stepped-cutter holes + bosses); when iterating,
override params from the command line instead of editing the file, e.g.:

```
openscad.com -D "num_holes=2" -D "divider_after_hole=[]" --render -o test.stl box.scad
```

Unless asked to verify, prefer implementing the requested change directly
and let the user render/check it themselves rather than running a full
render loop.
