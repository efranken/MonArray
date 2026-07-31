# monarray

OpenSCAD models for an arched, multi-driver speaker/BMR enclosure and its
trim piece. Fusion 360 was the original source (see `ExportedParameters.csv`
references in comments); this repo re-derives the geometry parametrically.

## The model being generated

Physically, this is a horizontal line-array speaker bar: a single long,
gently arched enclosure holding `num_holes` (currently 10) 2" Tectonic
BMR drivers in a row along its concave arc face. `divider_after_hole`
splits the hollow interior into separate sealed acoustic chambers (e.g.
outer banks for music, a center pair for a work computer) so each
driver/group has its own airspace. See `README.md` for the plain-English
"what is this" version.

The three printed/assembled parts:
- **`box.scad`** — the arched bar itself. Hollow-shelled, BMR cutouts
  through the arc face, internal dividers between chambers, mounting
  bosses behind each driver hole (for `trim.scad` to clip onto), and an
  **open back** (no rear wall) so the chambers are accessible during
  assembly/wiring, ringed by a perimeter lip and M3 heat-set insert holes.
- **`backpanel.scad`** — the flat cover that bolts over that open back
  into the M3 inserts, closing the chambers back up. All 8 speaker wires
  (2 per chamber) run through straight internal channels, tightly stacked
  in a single column, into a round riser tube standing next to a
  **keystone jack mount**, used as a cheap 8-position punch-down block.
  The cutout goes straight through the panel itself (`panel_thick`
  doubles as the keystone-rated mounting wall) so the jack — and a patch
  cable plugged into it — is reachable from the panel's *exterior* face;
  the housing extends inward from there into the box for the rest of the
  jack's length, ending at the punch-down terminal, which stays buried
  (wired once during assembly, same as a normal keystone install).
  Earlier revisions had this backwards (cutout buried at the deep end, no
  path to the exterior at all — caught because nothing could ever plug
  into it); don't reintroduce that. Also earlier, the wire channels fed
  straight into the jack's own body cavity — which turned out to be
  unusable, since that cavity is the jack's friction-fit footprint with
  no free space once it's actually inserted; the riser tube exists
  specifically to keep the wire path and the jack's body from competing
  for the same volume. The intended seal strategy (not yet modeled in
  geometry): dab silicone at each channel's chamber-side terminus after
  wiring to keep the 4 chambers acoustically isolated, plus a bead around
  the keystone recess's own opening.
- **`trim.scad`** — a stepped cap that plugs into a BMR bore from
  outside and clips onto the box's mounting bosses, capping each driver
  hole from the front. Its flange is a rounded rectangle (hull of the 4
  boss circles) rather than a plain disc, so it hugs the boss layout
  instead of needing its own diameter parameter.

`backpanel_section.scad` is not a fourth physical part — it's
`backpanel.scad` sliced through half its thickness (right at the depth
the channels sit) purely so the channel/keystone layout can be inspected
visually; see `images/three_pieces.png` (embedded in `README.md`), which
was generated from it (predates this rework, so it still shows the old
hub-based design).

## Files

- `params.scad` — every parameter for all pieces, in four blocks:
  Shared (bore/boss geometry used by box + trim), Box-only, Trim-only,
  Backpanel-only (this last one now covers both the wire-channel system
  and the `ks_*` keystone-mount block). `box.scad`/`trim.scad`/
  `backpanel.scad` all `include <params.scad>` (not `use`, since
  `include` also pulls in plain variables, not just modules/functions).
  **When adding a parameter, put it here, in the right block — never
  hardcode a value directly in one of the model files.**
- `box.scad` — the arched hollow bar: concave-arc profile, extruded,
  shelled hollow, with BMR cutouts on the arc face, an open back (no rear
  wall) with a perimeter lip, M3 heat-set insert holes around that rim,
  optional internal dividers, and mounting bosses on the arc-side facets.
- `backpanel.scad` — flat cover for the box's open back: mounting holes
  matching the box's M3 inserts (same `rect_pattern`/`rim_mid` derivation,
  duplicated from `box.scad` since `include`/`use` won't share derived
  geometry cleanly across files), the internal wire channels, and the
  keystone jack housing (`keystone_cutout()` goes through the panel
  itself, `keystone_housing()`/`keystone_body_cavity()` extend inward
  from there). **Wire-channel design rule (hard requirement from the
  user):** each of the 8 channels must be a single continuous,
  junction-free lumen with only gentle tangent-continuous sweeps — a
  Cat5e strand is push-threaded through, so no sharp elbows, no shared
  segments, no bores that merge or converge at shallow angles. The
  implementation is a cable-loom "bus": stacked parallel horizontal
  bores from the riser outward, each peeling off at its chamber via a
  `channel_bend_r` in-plane arc into a `channel_exit_r` arc that
  surfaces through the inner face as an angled entry hole. Peel order
  equals stack order (rank-by-distance: farther chambers ride lower),
  left-of-riser chambers enter the riser from the opposite side and
  reuse bus heights (stack of 6, not 8). The channels do **not** gather
  into `keystone_body_cavity()` — that's the jack's own friction-fit
  footprint, with no free space once the jack is inserted — but into
  `channel_riser_bore()`/`channel_riser_housing()`, a separate tube
  below the housing. An `assert()` at the bottom of the file checks
  `ks_jack_len` (the keystone's total protrusion, measured from the
  panel's own outer face) against the shallowest chamber's available
  depth (`bar_depth - wall_width`, worst case at `x=0`) and fails the
  render if it doesn't fit.
- `backpanel_section.scad` — inspection-only half-section of
  `backpanel.scad` (see above); `use`s it rather than duplicating it.
- `box_print.scad` / `backpanel_print.scad` — print-ready segments for a
  300mm printer (Creality K2 Pro): set `segment = 0..3`, export each.
  They `use <>` the model files (so the model isn't instantiated twice)
  and read derived values through small `box_*()`/`bp_*()` accessor
  functions defined in the model files — `use` exports functions but
  not top-level variables, so any new derived value a print file needs
  gets an accessor, never a re-derivation. Cut positions live in
  `params.scad` (`box_cut_after_hole` as "gap after hole N", with
  divider-carrying gaps cutting at the divider face so that joint mates
  against a full bulkhead; `panel_cuts` as literal x, staggered ≥~50mm
  off the box cuts so the bolted panel bridges every box joint). Joint
  features (filament-dowel holes; per-channel seam funnels in the
  panel) are subtracted from the *full* model before slabbing, so
  mating segments automatically get mirror halves. Box segments print
  standing on their cut face (all walls vertical, no supports; end
  segments stand on their closed end); the panel prints flat, outer
  face down. Asserts verify every cut clears bores/inserts/bolt
  holes/keystone zone and crosses channels only mid-bus.
- `trim.scad` — a stepped cap that plugs into a BMR bore from outside and
  clips onto the box's mounting bosses; flange is a rounded-rect hull of
  the boss circles, bore has a chamfered entry (`trim_id_chamfer`).
- `render.sh` — convenience wrapper: `openscad --render --imgsize=1000,1000
  --autocenter --viewall -o out.png file.scad [-- extra args]`. Requires
  `openscad` on `PATH`; in this dev environment it isn't (only
  `C:\Program Files\OpenSCAD\openscad.com` exists), so use the full path
  directly here rather than the script until that's resolved.

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
- The coincident-face risk isn't limited to subtraction: **unioning** an
  added feature exactly flush against an existing solid's boundary (zero
  gap, zero overlap) is the same problem and can make CGAL grind for a
  very long time instead of erroring — much easier to miss than a bad
  subtraction since the model can still look fine in F5 preview and even
  render "successfully," just extremely slowly. Found twice so far: the
  keystone `channel_riser_housing()` was placed at exact tangency to
  `keystone_housing()`'s outer wall (fixed with a 0.1mm overlap), and
  `back_lip()`'s outer cube was defined to land exactly on all 4
  boundaries where the surrounding end-wall/cap-wall material begins —
  worse than the riser case since it's 4 coincident planes at once
  (fixed the same way, `eps = 0.1` pulling each outer face slightly into
  the neighboring solid). If a render is unexpectedly slow (minutes, not
  seconds) and nothing else has changed much, check newly-added
  union'd geometry for exact-tangency placement before assuming it's just
  inherent model complexity.
- Two more shapes of the same disease, both found in the wire channels:
  (1) **coaxial same-diameter cylinders** overlapping along a shared
  axis (e.g. several channels routed through one transit line, or a
  pair of vertical drops at the same x) — their lateral surfaces are
  exactly coincident over the overlap, the curved-surface version of a
  coincident face; (2) **tangent-continuous segments** (a straight bore
  overlapping into an arc it's tangent to) — the overlap region is a
  near-zero-thickness crescent. Fix for (1): give every bore its own
  distinct axis, full stop. Fix for (2): don't overlap tangent segments
  directly; pull each segment ~0.4mm short and bridge the joint with a
  slightly fatter sphere, which both solids cross transversally.
- A small overlap that's safe for flat-on-flat is NOT automatically safe
  for curved-on-flat: a cylinder nudged 0.1mm into a flat face makes a
  lens ~2.4mm wide tapering to knife-edges (worse than the tangency it
  replaced). Curved-into-flat overlaps need to be ~1mm+ deep so the lens
  is wide and thick (see `riser_overlap`).
- While chasing the above: `stepped_cutter()` references `bmr_fn` (its
  local `$fn` override for the BMR cutout resolution), but `bmr_fn` had
  gone missing from `params.scad` entirely — OpenSCAD only warns
  ("Ignoring unknown variable"), it doesn't error, so the file still
  compiled and rendered, just with the BMR holes silently falling back to
  the low global `$fn` instead of their intended higher resolution.
  Re-added to `params.scad`. Worth a quick scan for other
  warnings-not-errors like this after any manual edit to `params.scad`.
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
- `trim.scad`'s flange (`flange_outline()`) is a `hull()` of 4 circles
  centered on the boss positions — a clean way to get a rounded-rect
  shape whose corner radius is guaranteed to exactly match another
  radius (here, `boss_od/2`) with no separate fillet parameter to keep
  in sync. Reach for this pattern before adding a manual
  rounded-rectangle polygon when the fillet needs to match existing
  circular geometry.
- The keystone mount in `backpanel.scad` is the first feature that
  *adds* material proud of a face (`keystone_housing()` extending inward
  past `panel_thick`) rather than being carved into the panel's own
  volume — a different shape than everything else in this repo, which is
  why it needs its own union of `panel_body()` + `keystone_housing()`
  before the usual cutter union is subtracted. Worth remembering if
  another external-standoff feature gets added: it has to join that
  first union, not the cutter one.
- When a feature needs to be reachable from a part's true exterior (a
  jack, a button, anything a person or cable touches after final
  assembly), trace the actual opening all the way through to that
  exterior face before trusting the geometry — it's easy to build a
  cavity that's internally consistent (tang catches correctly, cutter
  merges cleanly, compiles with no errors) while still being completely
  sealed off from the outside world. The first keystone mount did exactly
  this: its only opening faced *further into* the box instead of out to
  where a cable could ever reach it, and nothing in the geometry itself
  (no errors, no failed asserts) signaled that.

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
