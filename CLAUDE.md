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

The three printed/assembled parts (live models: `box.scad`,
`backpanel.scad`, `trim.scad`):
- **the box** — the arched bar itself. Hollow-shelled, BMR cutouts
  through the arc face, internal dividers between chambers, mounting
  bosses behind each driver hole (for the trim caps to clip onto), and an
  **open back** (no rear wall) so the chambers are accessible during
  assembly/wiring, ringed by a perimeter lip and M3 heat-set insert holes.
- **the backpanel** — flat cover bolted over the open back into the M3
  inserts. All 8 speaker wires (2/chamber) run through stacked internal
  channels into a riser tube beside a **keystone jack mount** (used as an
  8-position punch-down block). The cutout goes through the panel itself
  so the jack is reachable from the *exterior* face; the housing extends
  inward to the punch-down terminal. Don't reintroduce two past bugs:
  (1) cutout facing into the box instead of out (nothing could plug in),
  (2) wire channels feeding into the jack's own friction-fit cavity
  instead of the separate riser (no free space once the jack's inserted).
  Seal strategy (not yet modeled): silicone at each channel's
  chamber-side end, plus a bead around the keystone recess.
- **the trim** — a stepped cap that plugs into a BMR bore from
  outside and clips onto the box's mounting bosses, capping each driver
  hole from the front. Its flange is a rounded rectangle (hull of the 4
  boss circles) rather than a plain disc, so it hugs the boss layout
  instead of needing its own diameter parameter.

## Folder structure

```
params.scad             all user-tunable parameters (single source of truth)
common.scad             shared derived geometry + helpers (includes params.scad)
box.scad                } the LIVE models -- each includes common.scad
backpanel.scad          }
trim.scad               }
box-split-{1,2,3}.scad       box.scad cut into 3 printable pieces, one file
                              per piece (use <box.scad>) -- see box.scad's
                              box_outer_wall_mid_x()
backpanel-split-{1,2,3}.scad backpanel.scad cut into 3 folded pieces, one file
                              per piece (use <backpanel.scad>) -- see
                              backpanel.scad's panel_piece()
archive/              retired originals: box/backpanel/trim.scad (the
                      pre-simplification versions the current files were
                      verified identical against), box_print.scad,
                      backpanel_print.scad, backpanel_section.scad, plus a
                      later smp-*.scad snapshot (pre "/-\" rear shape)
scripts/render.sh     re-renders every STL in stl/ from its matching root
                      .scad file, overwriting in place (nightly + Manifold,
                      same detection as "Rendering / verification" below)
stl/                  exported STLs -- snapshots, not regenerated
                      automatically; run scripts/render.sh after a change
                      that affects geometry to bring them back in sync
images/               renders embedded in README.md
```

**Files in `archive/` no longer compile in place**: their
`include <params.scad>` / `use <box.scad>` references resolve relative
to their own directory, and those targets are at root (or archived under
different assumptions). They're reference history, not live code. The
print files (`box_print.scad` / `backpanel_print.scad`) and the
`backpanel_section.scad` inspection slice went to archive with the
originals — to restore any of them, copy to root and repoint their
`use <>` at the root files (module and accessor names are unchanged, so
that's the only edit needed; note `box-split-*.scad`/`backpanel-split-*.scad`
now cover this same 3-piece-print need directly, so restoring these is
only needed for the old 4-piece scheme). Their sectioning parameters
(`box_cut_after_hole`, `panel_cuts`, `joint_pin_*`, `joint_funnel_*`)
still live in `params.scad`, ready for that.

## Files (live)

- `params.scad` — every parameter, in blocks: Shared bore/boss geometry,
  Box-only, Trim-only, Backpanel-only (wire-channel system + `ks_*`
  keystone mount), Sectioning. Reached via `include` chain
  (piece → common → params), so plain variables flow through.
  **When adding a parameter, put it here, in the right block — never
  hardcode a value directly in a model file.**
- `common.scad` — everything derived or shared: the arc solve
  (`R`, `half_deg`, `Xe`, `Yc`, `Xi`, `d_in`), BMR hole layout
  (`hole_t()`, `hole_x()`, pitch + overlap assert), `rect_pattern()`,
  `boss_xy()`, `entry_bore()`. Derived values belong here the moment a
  second file needs them.
- `box.scad` — the arched hollow bar: concave-arc profile (with a "/-\"
  rear -- flat across the center chamber, angled down to `rear_end_depth`
  at each end), extruded, shelled hollow (faceted cavity, one flat facet
  per hole), BMR cutouts and mounting bosses on the arc face, open back
  with a seating lip (`back_lip()`), divider walls, M3 insert holes
  (`box_rim_bolt_frame()`). Carries the `box_*()` accessors that
  `box-split-*.scad` and `backpanel.scad` read via `use <>`.
- `backpanel.scad` — cover for the box's open back, built flat in one
  frame (bolt holes via `box_rim_bolt_frame()`, the through-panel
  keystone jack mount, the wire channels) then cut into 3 pieces and the
  two end pieces folded to match `box.scad`'s rear bend (`panel_piece()`,
  `rotate_about_x()`). **Hard requirement:** each of the 8 channels must
  be a single junction-free lumen with only gentle sweeps — a Cat5e
  strand is push-threaded through, so no sharp elbows, no shared/merging
  segments. Implementation is a cable-loom "bus": stacked bores from the
  riser outward, each peeling off at its chamber via a `channel_bend_r`
  arc into a `channel_exit_r` arc that surfaces as an angled entry hole.
  Channels gather into `channel_riser_bore()` — **not**
  `keystone_body_cavity()` (the jack's own friction-fit footprint, no
  free space once inserted). Carries the `bp_*()` accessors for the
  (archived) print file.
- `trim.scad` — per-driver cap: rounded-rect flange (hull of the 4
  boss circles), plug into the BMR bore, chamfered `trim_id` opening,
  countersunk screw holes via `entry_bore()`.

## Comment style

Keep `.scad` comments short: 1-3 lines, WHY not WHAT. Don't restate what
the next line obviously does, don't narrate history ("originally X, then
we changed to Y"), don't write multi-paragraph derivations inline. If a
design decision needs more than a few lines to explain, put the full
version in this file (CLAUDE.md) and leave a one-line pointer in the
code. This applies to all `.scad` files and to edits to this file too —
prefer a tight bullet over a paragraph.

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
- Coincident faces aren't just a subtraction risk: **unioning** a feature
  exactly flush (zero gap/overlap) against existing solid can make CGAL
  grind for minutes instead of erroring, even though F5 preview looks
  fine. Fix: `eps ~= 0.1` overlap into the neighbor. Seen in
  `channel_riser_housing()` vs `keystone_housing()`, and `back_lip()`'s
  outer cube (4 coincident planes at once). If a render goes
  unexpectedly slow, check newly-added union'd geometry for tangency.
- Same disease, curved version: (1) coaxial same-diameter cylinders
  overlapping on a shared axis — give every bore its own axis; (2)
  tangent-continuous segments (a bore overlapping an arc it's tangent
  to) leave a near-zero-thickness crescent — pull each segment ~0.4mm
  short and bridge with a slightly fatter sphere instead.
- A safe flat-on-flat overlap is NOT safe curved-on-flat: a cylinder
  nudged 0.1mm into a flat face makes a knife-edge lens. Curved-into-flat
  needs ~1mm+ overlap (see `riser_overlap`).
- OpenSCAD warns ("Ignoring unknown variable") but doesn't error on a
  missing param — `bmr_fn` going missing from `params.scad` silently
  dropped BMR holes to the low global `$fn` and still rendered. Scan for
  warnings after any manual `params.scad` edit.
- A union of two cylinders fed into `rotate_extrude()` leaves an internal
  seam that can corrupt STL export even though preview looks fine —
  `stepped_cutter()` uses one continuous polygon revolved once instead.
- F5 preview can visually fail to show a cut correctly in a deeply
  nested boolean tree even when the CSG is correct — verify with F6
  (render) before assuming geometry is broken.
- `flange_outline()`'s `hull()` of 4 boss-centered circles is a clean way
  to get a rounded-rect whose corner radius exactly matches another
  radius (`boss_od/2`) with no separate fillet param to keep in sync.
  Reach for this before a manual rounded-rectangle polygon.
- Features that *add* material proud of a face (`keystone_housing()`)
  need their own union with the base body, ahead of the usual cutter
  union — don't fold them into the cutter side.
- Trace a reachable-from-exterior feature (jack, button) all the way to
  that exterior face before trusting the geometry — a cavity can be
  internally consistent (no errors, no failed asserts) while still
  sealed off from the outside. The first keystone mount opened *into*
  the box instead of out to a cable.

## Provenance (simplified rewrite, verified identical)

The current `box`/`backpanel`/`trim`.scad files are a level-set rewrite
of the original three piece files (now in `archive/`, along with an
interim `smp-*.scad`-prefixed snapshot from before the prefix was
dropped): `common.scad` absorbed everything that
was duplicated or repeated (the arc solve and `rect_pattern` existed
twice verbatim; the rim-bolt-point math twice; the boss-position
expression 4x; the chamfered entry bore twice), and the piece files
kept the same module structure minus the duplication, with
`shell_cavity(rear_cut)` folding the old cavity/cavity_cut pair.
**Verified geometrically identical to the archived originals** at the
time of the swap (method below). Module and accessor names were kept
identical, which is what makes restoring the archived print files a
one-line repoint.

## Simplification workflow (apply proactively, not retroactively)

This is the process that produced the current files, kept here as a
first-class practice so it's applied *as new features are designed*,
not run as a one-time cleanup pass after several features have already
stacked up duplicated logic.

1. **Read every file end-to-end before touching anything.** Duplication
   across files is invisible if you edit one file at a time from memory.
2. **Find every derived value/shape a second file needs, and ask "is
   this in the shared file yet?"** before writing it inline. The
   original box/backpanel/trim had the arc solve, `rect_pattern`, the
   rim-bolt-point math, the boss-position expression, and a chamfered
   bore all duplicated — none of that was a design decision, it
   accreted. **Rule: the moment a second file needs a derived value, it
   moves to `common.scad` immediately**, not at the next refactor.
3. **Prefer a generic geometric operation over a hand-derived one when
   one exists** (this session's concrete example: `offset()` for a
   profile inset, replacing a hand-maintained inner polygon — see the
   dynamic-shell section below). A generic operation automatically
   tracks upstream shape changes; a hand-derived one has to be
   remembered and re-derived every time the upstream shape changes.
4. **Keep module/function names stable across a rewrite.** Every
   consumer (print files, section views) then needs only a `use <>`
   repoint, not a rewrite, and old and new versions stay drop-in
   comparable.
5. **Verify equivalence before trusting a rewrite** — see the CSG-tree
   diff method below. Don't rely on "it renders" or a visual check.
6. **Archive, don't delete**, the pre-rewrite version until the new one
   has actually been used for a while — it's the ground truth the
   verification method compares against, and a fallback if the rewrite
   has a subtle behavioral gap the verification didn't happen to check
   (e.g. a `use <>` accessor an archived consumer needs that never got
   ported — verification only proves the *rendered geometry* matches).

The test for whether a new feature belongs in `common.scad` from
day one: **"if I change this upstream value/shape, does anything
downstream need to also change to stay correct?"** If yes, that
downstream relationship should be expressed as a function/generic
operation on the upstream value, not as a second hand-computed
constant — see the dynamic-shell rework below for a worked example of
converting an existing hand-synced relationship into one that isn't.

## Verifying a refactor produces identical geometry

Fast, near-proof method (seconds): export both versions' **CSG trees**
(`openscad -o x.csg x.scad` — compile only, no mesh), normalize
`group()` → `union()`, strip pure-wrapper lines (`union() {` / `}`),
and diff. Zero differing primitive/transform lines = every cylinder,
cube, polygon, and transform with all literal numbers is identical in
content and order. Wrapper-only residue comes from implicit vs
explicit unions and is geometrically meaningless (calibrated against a
mesh-XOR-proven-identical pair).

What NOT to do: (1) STL byte/hash comparison — identical solids
tessellate differently when tree nesting differs; even vertex *sets*
differ. (2) Mesh-level XOR via `import()` of both STLs — float
roundtrip makes the meshes *almost* coincident, CGAL's worst case
(asserts or grinds). (3) Full-scale CSG-level XOR
(`difference(){A();B();}` via module-wrapped includes) — exact and
definitive, and fine for small parts (proved the trim pair), but
differencing two exactly-coincident copies of a large part takes
30+ min in OpenSCAD 2021.01. The module-wrap trick itself is useful:
`module A() { include <box.scad> }` scopes a whole file, and
param overrides placed after the include apply to that scope
(last-assignment-wins).

**When the CSG-tree diff shows real differences (not just wrapper
noise), it means the tree *structure* changed, not necessarily the
*geometry*** (e.g. a `polygon()` replaced by `offset()`) — the CSG diff
can't tell those apart, since it compares operations, not resulting
shape. When that happens, scope a 2D or 3D XOR check to just the piece
that changed (see below) instead of trying to CSG-diff the whole part.

## Dynamic shell: cavity_2d() as offset() + hand-derived facets

`box.scad`'s cavity boundary is two kinds of edge: the **arc side**
is one hand-derived flat facet per hole (`facet_pts`/`facet_cap_2d()`,
driven by hole positions, not a generic inset); the **rear+ends** are a
genuine `offset(delta = -wall_width, chamfer = false)` of whatever
`profile_2d()`'s lower portion is (`outer_cap_2d()`/`outer_cap_open_2d()`),
so the cavity reacts automatically if that shape changes — no
hand-written `[Xi,0]`/`[-Xi,0]` polygon to re-derive by hand. Worked
example for principle #3 below. They meet at `cap_y`, a margin below
the lowest facet point; the file's `assert` catches a future rear-end
feature growing taller than `cap_y`.

`offset()` gotchas: (1) it insets *every* edge, including the 3 rear
segments, which must stay flush — fixed in `outer_cap_open_2d()` by
unioning in a plain oversized rectangle hugging each segment's outward
side (plus a small disc at each of the 2 true outer corners, where a
rear segment meets the curved arc rather than another straight segment)
before offsetting, so there's solid material well past every rear edge
and offset() has nothing there to inset; re-intersect with the
un-bloated shape afterward to discard the rectangles'/discs' spillover.
(**Don't** mirror the whole shape across each segment's line instead —
tried that first; it drags the far-away arc boundary along too, which
isn't mirror-symmetric across a rear segment's line, and left an
uncancelled wedge of material right at the two true outer corners that
was invisible in coarse checks and only showed up as a real "solid
plane over the back" once someone actually rendered and inspected the
STL.) (2) clipping with a box *before* offsetting inward: the offset
eats exactly `wall_width` off that clip edge too, so pad the clip box by
at least `wall_width` past where the result needs to reach.

`edge_deg` in `common.scad` takes the max of the original `end_space`
margin and an exact chord-based margin that keeps the outermost hole's
OD clear of the box ends, so hole layout auto-adjusts instead of
silently overlapping the corner.

(An earlier bottom/end-chamfer rear treatment — `end_profile_2d()` /
`end_cavity_2d()`, offsetting in the (x,z) plane — was replaced by the
current "/-\" rear shape, driven by `rear_segments` in `box.scad`
directly off `profile_2d()`'s own (x,y) plane instead of needing a
second axis's worth of offset machinery. See `angle-*.scad` in
`archive/` for that design if it's ever needed again.)

## Rendering / verification

**Default to not rendering at all.** Make the edit, stop. The user
reviews visually in seconds; a `--render` + screenshot round trip costs
minutes, and it's real money/time to burn on every edit by default. Only
render/screenshot when the user explicitly asks to verify/check/render —
and even then, run exactly one targeted check, not a battery of
full-model + reduced-param + preview + zoomed + numeric-echo checks for
the same fact. Don't iterate blindly on camera coordinates trying to
frame a shot — if it's not right in one or two tries, say so and let the
user look instead of continuing to guess.

If there's real doubt a `.scad` file still parses after an edit, a
compile-only pass is enough and is near-instant — no `--render`, no
mesh:

```
openscad.com -o test.csg box.scad
```

**Two OpenSCAD installs are on this machine — use the nightly one for
any real render.** `C:\Program Files\OpenSCAD\openscad.com` is the old
2021.01 stable: CGAL-only backend, exact rational arithmetic, and
genuinely slow on this project (`box.scad`'s full render is 4-5+
minutes — arc profile + 10 stepped-cutter holes + bosses + unions).
`C:\Program Files\OpenSCAD (Nightly)\openscad.com` defaults to the
**Manifold** backend (float-based, still watertight) and renders the
exact same geometry in well under a second (measured: `box-split-1.scad`
0.7s nightly vs. 4:44 stable). Use the nightly build's `openscad.com` for
`--render`/STL export; fall back to the stable one only if the nightly
build is ever missing. Override params from the command line rather than
editing the file:

```
"C:\Program Files\OpenSCAD (Nightly)\openscad.com" -D "num_holes=2" --render -o test.stl box.scad
```

`scripts/render.sh` already does this detection automatically (nightly +
`--backend Manifold`, falling back to whatever `openscad` resolves to on
PATH with a warning) — prefer it over calling `openscad.com` directly when
re-rendering the STLs in `stl/` after a geometry change; it re-renders
every STL there from its matching root `.scad` file, overwriting in
place. For a one-off PNG render instead, call `openscad.com --render
--imgsize=... -o out.png file.scad` directly.

**If the nightly build is missing or stale**, get a current one from
`https://files.openscad.org/snapshots/` (Windows: the `...-Installer.exe`
file with the newest date) and install it — it installs side-by-side
with the stable release, doesn't replace it, and nothing else here needs
to change (same file paths, same flags). Manifold is its default backend
already; no separate setup needed after install.
