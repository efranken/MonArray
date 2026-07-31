// ============================================================
// Hollow box with one arced face, circle cutouts on the arc face
// Parameterized from ExportedParameters.csv (Fusion 360 export)
//
// Modeling process (mirrors the Fusion workflow):
//   1. Create profile: rectangle whose top face is a CONCAVE arc
//      (dips arc_depth at mid-span; flat bottom, flat ends)
//   2. Extrude it height
//   3. Shell it to wall_width (closed hollow, walls all around)
//   4. Circle cutouts through the arc face wall
//
// Computational-efficiency notes:
//   - $fn (params.scad) is kept low globally since most circular
//     features here are small hardware (bosses, pilot holes, insert
//     holes) that don't need many facets. The one feature that does
//     (the large BMR cutout) gets its own higher-resolution override,
//     bmr_fn, scoped locally in stepped_cutter() -- see below.
//   - Every repeated feature is defined once as a module/function and
//     instantiated per position via a small positioning loop
//     (per_hole_frame(), dividers(), m3_insert_holes()) rather than
//     inlined per-instance -- OpenSCAD still tessellates each instance
//     independently, but this keeps geometry definitions single-sourced
//     and avoids redundantly recomputing shared shapes (see dividers()).
// ============================================================

// All parameters (primary geometry, options, dividing walls, back lip,
// mounting bosses) come from params.scad, shared with trim.scad.
include <params.scad>

// ---------- Derived arc geometry ----------
// Solve (1-cos a)/(2a) = sagitta/arc_length for half-angle a (radians)
// via bisection. Then R = arc_length / (2a).
function f(a) = (1 - cos(a * 180 / PI)) / (2 * a);
function solve_a(t, lo, hi, i = 0) =
    i > 60 ? (lo + hi) / 2 :
    f((lo + hi) / 2) < t ? solve_a(t, (lo + hi) / 2, hi, i + 1)
                         : solve_a(t, lo, (lo + hi) / 2, i + 1);

half_angle_rad = solve_a(arc_depth / arc_length, 1e-6, PI / 2);
R        = arc_length / (2 * half_angle_rad);   // arc face radius
half_deg = half_angle_rad * 180 / PI;           // half sector angle
Xe       = R * sin(half_deg);                   // half chord (box half-length)
Yc       = bar_depth + R;                       // arc circle center (above)
// arc face: y = Yc - R*cos(t) -> lowest (bar_depth) at mid, ends at
// bar_depth + arc_depth. Flat bottom at y = 0.

// ---------- Hole layout (along the arc face) ----------
// First hole's left edge sits end_space from the left end; last hole's
// right edge sits end_space from the right end. Centers fill the
// remaining span equidistantly for any num_holes.
edge_deg  = (end_space + bmr_id / 2) / R * 180 / PI;
hole_span = 2 * (half_deg - edge_deg);   // first center -> last center
pitch     = num_holes > 1 ? hole_span * PI / 180 * R / (num_holes - 1) : 0;

echo(str("R = ", R, " mm | chord = ", 2 * Xe, " mm | holes = ", num_holes,
         " | pitch = ", pitch, " mm"));
assert(num_holes < 2 || pitch > bmr_id,
       "Holes overlap: reduce num_holes or bmr_id");

// ---------- Step 1: profile (box with concave arc top) ----------
module profile_2d() {
    n = 64;
    polygon(concat(
        // concave arc face, left to right (dips at mid-span)
        [for (i = [0:n]) let (t = -half_deg + 2 * half_deg * i / n)
            [R * sin(t), Yc - R * cos(t)]],
        // right end down, flat bottom, left end up
        [[Xe, 0], [-Xe, 0]]));
}

// hole angular position (0-indexed) along the arc, matching arc_face_holes()
function hole_t(i) = -hole_span / 2 + (num_holes == 1 ? 0
                        : hole_span * i / (num_holes - 1));

// ---------- Accessors for box_print.scad ----------
// box_print.scad pulls the box in with `use <>` (so the model isn't
// instantiated twice), which exports functions/modules but not top-level
// variables -- these accessors expose the derived values it needs.
function box_Xe() = Xe;
function box_hole_x(i) = R * sin(hole_t(i));   // chord x of hole i (0-indexed)
// outer arc-face depth (final-part z) at chord position x
function box_face_y(x) = Yc - sqrt(R * R - x * x);
// print-cut x for the gap after hole h (1-indexed): the gap midpoint,
// unless that gap carries a divider, in which case the cut lands at the
// divider's +x face so one segment keeps the divider as a mating bulkhead
function box_gap_cut_x(h) =
    let (xm = R * sin((hole_t(h - 1) + hole_t(h)) / 2))
    len([for (d = divider_after_hole) if (d == h) d]) > 0
        ? xm + divider_thickness / 2 : xm;

// ---------- Shared per-hole placement ----------
// Every arc-face feature (the BMR cutout, its mounting bosses, and the
// boss screw holes) sits at the same local frame per hole: z runs along
// the hole axis into the cavity, y is the model's height (vertical),
// origin z = 0 at the outer arc surface, facet plane at z = wall_width.
// Defining this transform
// chain once and reusing it (instead of repeating it per feature) means
// each feature module only has to describe its own shape, not re-derive
// its position.
module per_hole_frame() {
    for (i = [0:num_holes - 1])
        translate([0, Yc, 0])
            rotate([0, 0, hole_t(i)])
                translate([0, -R, height / 2])
                    rotate([90, 0, 0])
                        children();
}

// Stepped cutter: a single solid of revolution (bmr_id for the first
// baffle_space, then bmr_od for the rest), *not* a union of two separate
// cylinders. A union of two cylinders here -- even done in local coordinates
// -- leaves an internal seam that CGAL resolves fine for the F6 preview but
// silently corrupts during STL mesh export (subtracting a shape built from
// a union is a known robustness weak spot). rotate_extrude() of one profile
// has no internal seam, so it survives export cleanly.
// Behaves like a plain cylinder() sitting on z=0 extending in +z.
module stepped_cutter() {
    $fn = bmr_fn;               // the one feature worth spending facets on
    od_depth = wall_width + 8;  // generous: the faceted wall is thicker than
                                // wall_width away from hole centers, so reach
                                // well past the cavity for a clean cut
    rotate_extrude(convexity = 4)
        polygon([
            [0,          -2],
            [bmr_id / 2, -2],
            [bmr_id / 2, baffle_space],
            [bmr_od / 2, baffle_space],
            [bmr_od / 2, od_depth],
            [0,          od_depth],
        ]);
}

// ---------- Step 4: stepped circle cutouts through the arc face ----------
// bmr_id is the trim on the outward face, baffle_space deep.
// bmr_od picks up exactly where the trim stops and cuts the rest of the way
// through the wall.
module arc_face_holes() {
    per_hole_frame()
        stepped_cutter();
}

// ---------- Faceted cavity: a flat flange behind each hole ----------
// The cavity's arc-side surface is a polygonal (faceted) approximation of
// the arc: one flat facet per hole, tangent to the inner-arc circle
// (radius R + wall_width) at that hole's angular position, so the facet is
// perpendicular to the hole axis and the wall is exactly wall_width thick
// at each hole center (growing slightly toward the facet edges). Facets
// meet at the angular midpoints between adjacent holes; the first and last
// facets extend all the way to the cavity end walls.
d_in = R + wall_width;        // inner-arc radius (tangency radius of facets)
Xi   = Xe - wall_width;       // cavity half-length (end walls inset)

// point at "radius" r, arc angle t (deg), in profile coordinates
function arc_pt(r, t) = [r * sin(t), Yc - r * cos(t)];

// intersection of the tangent facet line at angle t with vertical x = x0
function facet_end(t, x0) =
    let (s = (x0 - d_in * sin(t)) / cos(t))
        [x0, Yc - d_in * cos(t) + s * sin(t)];

// cavity profile: faceted top (left -> right); open at the bottom (no back
// wall), flush with the rear at y = 0
module cavity_2d() {
    polygon(concat(
        // left end wall meets facet 1
        [facet_end(hole_t(0), -Xi)],
        // facet i meets facet i+1 at the angular midpoint between holes
        [for (i = [0:num_holes - 2])
            let (tm = (hole_t(i) + hole_t(i + 1)) / 2,
                 dt = (hole_t(i + 1) - hole_t(i)) / 2)
                arc_pt(d_in / cos(dt), tm)],
        // facet 10 meets right end wall, then straight down to the open back
        [facet_end(hole_t(num_holes - 1), Xi),
         [Xi, 0], [-Xi, 0]]));
}

// shell cavity: wall_width inset on every face, faceted on the arc side,
// flush with the rear (y = 0). Used to clip additive features (e.g.
// dividers) so they never protrude past the rear plane.
module shell_cavity() {
    translate([0, 0, wall_width])
        linear_extrude(height - 2 * wall_width, convexity = 10)
            cavity_2d();
}

// shell_cavity(), extended 1 mm past the rear face -- subtraction only.
// cavity_2d()'s bottom edge is exactly coincident with profile_2d()'s flat
// bottom at y = 0; cutting flush against a coincident face risks a
// degenerate (non-manifold) boundary, so the actual carve reaches past it.
module shell_cavity_cut() {
    union() {
        shell_cavity();
        translate([-Xi, -1, wall_width])
            cube([2 * Xi, 1, height - 2 * wall_width]);
    }
}

// ---------- Dividing walls between selected hole pairs ----------
// A thin slab centered on the midpoint (by chord position) between two
// adjacent holes, clipped to the actual hollow cavity so it sits flush
// with the surrounding shell. shell_cavity() is a fairly expensive
// faceted linear_extrude; unioning all the divider slabs first and
// intersecting with the cavity once (instead of once per divider) avoids
// recomputing that extrude len(divider_after_hole) times for an
// identical result.
module dividers() {
    intersection() {
        union() {
            for (h = divider_after_hole) {
                t_mid = (hole_t(h - 1) + hole_t(h)) / 2;  // between hole h and h+1 (1-indexed)
                x_mid = R * sin(t_mid);
                translate([x_mid - divider_thickness / 2, -1, -1])
                    cube([divider_thickness, bar_depth + arc_depth + 2, height + 2]);
            }
        }
        shell_cavity();
    }
}

// ---------- Lip around the inside of the open back ----------
// A picture-frame rim, back_lip_width wide, reaching back_lip_depth into
// the cavity from the exposed back (y = 0), for a cover plate to seat
// against. The back opening is a plain rectangle here (Xi x (height -
// 2*wall_width)) -- well clear of the faceted arc region above it -- so a
// simple framed slab is all that's needed.
module back_lip() {
    inset = Xi - back_lip_width;
    z_lo  = wall_width + back_lip_width;
    z_hi  = height - wall_width - back_lip_width;
    eps   = 0.1;  // outer boundary is unioned in exactly where the
                  // surrounding end-wall/cap-wall material begins (x =
                  // +-Xi, z = wall_width/height-wall_width); overlapping
                  // slightly into that (already-solid) material on all 4
                  // sides avoids a bare coincident-face union there
    difference() {
        translate([-(Xi + eps), 0, wall_width - eps])
            cube([2 * (Xi + eps), back_lip_depth, height - 2 * wall_width + 2 * eps]);
        translate([-inset, -1, z_lo])
            cube([2 * inset, back_lip_depth + 2, z_hi - z_lo]);
    }
}

// ---------- M3 heat-set insert holes around the rear rim ----------
// n points equally spaced by arc length around the perimeter of a
// 2*hw x 2*hh rectangle centered at the origin, starting at top-center
// and going clockwise. n is the only thing that needs to change to
// add/remove holes.
function rect_pattern(n, hw, hh) =
    [for (i = [0:n - 1])
        let (s  = i * (4 * hw + 4 * hh) / n,
             s1 = hw, s2 = s1 + 2 * hh, s3 = s2 + 2 * hw, s4 = s3 + 2 * hh)
        s < s1 ? [s, hh] :
        s < s2 ? [hw, hh - (s - s1)] :
        s < s3 ? [hw - (s - s2), -hh] :
        s < s4 ? [-hw, -hh + (s - s3)] :
                 [-hw + (s - s4), hh]
    ];

// blind bore with a 45-deg entry chamfer, local z = 0 at the exposed rear
// face, increasing into the material (matches boss_hole_cutter's
// convention in trim.scad)
module m3_insert_hole() {
    r_chamfer_d = m3_ins_od + 2 * boss_chamfer;
    union() {
        // entry overhang, for a clean cut through the exposed rear face
        translate([0, 0, -1])
            cylinder(h = 1, d = r_chamfer_d);
        // 45-deg entry chamfer
        cylinder(h = boss_chamfer, d1 = r_chamfer_d, d2 = m3_ins_od);
        // straight bore for the rest of the depth
        translate([0, 0, boss_chamfer])
            cylinder(h = m3_ins_depth - boss_chamfer + 0.01, d = m3_ins_od);
    }
}

// Center rectangle: halfway between the rear face's outer bound (the box
// profile itself, Xe / z = 0, height) and inner bound (the back lip's
// inner edge, Xi - back_lip_width / z = wall_width + back_lip_width ...),
// so each hole sits centered in the combined wall + lip rim material.
module m3_insert_holes() {
    rim_mid = (wall_width + back_lip_width) / 2;
    hw = Xe - rim_mid;
    hh = height / 2 - rim_mid;
    for (p = rect_pattern(num_bolts, hw, hh))
        translate([p[0], 0, p[1] + height / 2])
            rotate([-90, 0, 0])
                m3_insert_hole();
}

// ---------- Mounting bosses on the facets ----------
// Four bosses per hole, centers on a bolt circle boss_bc_d around the hole
// axis, first boss clocked 45 deg from vertical (square arrangement).
// Because each facet is perpendicular to its hole's axis, every boss base
// sits flush on the flat facet -- no wedge gaps. Reuses per_hole_frame()
// for positioning (same local frame as the BMR cutout at that hole).
z_facet = wall_width;

module mounting_bosses() {
    per_hole_frame()
        for (ang = boss_angles)
            translate([boss_bc_d / 2 * sin(ang), boss_bc_d / 2 * cos(ang),
                       z_facet - 0.4])
                cylinder(h = boss_h + 0.4, d = boss_od);  // 0.4 embed: manifold weld
}

module boss_screw_holes() {
    top = z_facet + boss_h;   // boss face
    per_hole_frame()
        for (ang = boss_angles)
            translate([boss_bc_d / 2 * sin(ang), boss_bc_d / 2 * cos(ang), 0]) {
                // blind pilot hole
                translate([0, 0, top - boss_hole_depth])
                    cylinder(h = boss_hole_depth + 0.01, d = boss_hole_d);
                // 45-deg entry chamfer
                translate([0, 0, top - boss_chamfer])
                    cylinder(h = boss_chamfer + 0.01,
                             d1 = boss_hole_d,
                             d2 = boss_hole_d + 2 * boss_chamfer);
                // clear any z-fighting above the boss face
                translate([0, 0, top])
                    cylinder(h = 1, d = boss_hole_d + 2 * boss_chamfer);
            }
}

// ---------- Steps 2 + 3: extrude, then shell ----------
module arched_hole_bar() {
    // concave arc face up, flat bottom resting on Z=0, width along Y
    translate([0, height / 2, 0])
        rotate([90, 0, 0])
            difference() {
                union() {
                    difference() {
                        // extruded profile
                        linear_extrude(height, convexity = 10)
                            profile_2d();
                        // shell cavity (open back, cut past the rear face)
                        shell_cavity_cut();
                        // cutouts through the arc face wall
                        arc_face_holes();
                    }
                    // dividing walls between selected holes
                    dividers();
                    // lip around the inside of the open back
                    back_lip();
                    // trim-piece mounting bosses on the facets
                    mounting_bosses();
                }
                // pilot holes + chamfers through the bosses
                boss_screw_holes();
                // M3 heat-set insert holes around the rear rim
                m3_insert_holes();
            }
}

arched_hole_bar();
