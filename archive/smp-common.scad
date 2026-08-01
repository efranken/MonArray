// ============================================================
// Shared geometry for smp-box / smp-backpanel / smp-trim.
// ============================================================

include <params.scad>

// ---------- Arc geometry ----------
// Solve (1-cos a)/(2a) = sagitta/arc_length for half-angle a (radians)
// by bisection, then R = arc_length / (2a).
function f(a) = (1 - cos(a * 180 / PI)) / (2 * a);
function solve_a(t, lo, hi, i = 0) =
    i > 60 ? (lo + hi) / 2 :
    f((lo + hi) / 2) < t ? solve_a(t, (lo + hi) / 2, hi, i + 1)
                         : solve_a(t, lo, (lo + hi) / 2, i + 1);

half_angle_rad = solve_a(arc_depth / arc_length, 1e-6, PI / 2);
R        = arc_length / (2 * half_angle_rad);   // arc face radius
half_deg = half_angle_rad * 180 / PI;           // half sector angle
Xe       = R * sin(half_deg);                   // half chord (part half-length)
Yc       = bar_depth + R;                       // arc circle center
Xi       = Xe - wall_width;                     // cavity half-length
d_in     = R + wall_width;                      // facet tangency radius

// ---------- Bottom/end-face chamfer geometry ----------
// chamfer_dx: shared with smp-box.scad's end_profile_2d(). The rest is a
// hand-derived, closed-form mitered offset of end_profile_2d() by an
// arbitrary distance d, evaluated at height z -- everything else derives
// the same corner via a genuine offset() of end_profile_2d() (see
// smp-box.scad's end_cavity_2d()) instead, but rim_bolt_pts() below needs
// a z -> x function to place bolts on it, which offset()'s polygon
// output doesn't give for free.
chamfer_dx = box_chamfer_leg / tan(box_chamfer_angle);

function chamfer_ap(d)       = [Xe - chamfer_dx - d * sin(box_chamfer_angle), d * cos(box_chamfer_angle)];
function chamfer_z_outer(d)  = chamfer_ap(d)[1]
    + ((Xe - d) - chamfer_ap(d)[0]) / cos(box_chamfer_angle) * sin(box_chamfer_angle);
function chamfer_x_bottom(d) = chamfer_ap(d)[0]
    + (d - chamfer_ap(d)[1]) / sin(box_chamfer_angle) * cos(box_chamfer_angle);
// x of "end_profile_2d() offset inward by d" at height z -- Xe-d above
// the corner's miter point, tapering to chamfer_x_bottom(d) at z = d.
function chamfer_offset_x(d, z) =
    z >= chamfer_z_outer(d) ? Xe - d :
    chamfer_x_bottom(d) + (z - d) * ((Xe - d) - chamfer_x_bottom(d)) / (chamfer_z_outer(d) - d);

assert(chamfer_z_outer(wall_width) < height - wall_width,
       "the bottom chamfer reaches above the shelled band -- reduce box_chamfer_leg or steepen box_chamfer_angle");
assert(chamfer_x_bottom(wall_width) < Xi,
       "the bottom chamfer's relief wedge is degenerate -- reduce box_chamfer_leg or steepen box_chamfer_angle");

// ---------- BMR hole layout along the arc ----------
// First/last hole edges sit end_space from the ends; centers fill the
// remaining span equidistantly. Also keeps the outermost hole's full OD
// footprint clear of the bottom/end chamfer's x-reach (chamfer_dx) --
// otherwise the chamfer corner can eat into that hole's cutter/facet
// regardless of end_space, since end_space alone was sized before the
// chamfer existed and only accounts for bmr_id, not the wider bmr_od
// the chamfer can actually reach.
edge_deg_end  = (end_space + bmr_id / 2) / R * 180 / PI;         // arc-length margin
edge_deg_cham = half_deg - asin((Xe - chamfer_dx - bmr_od / 2 - 1) / R);  // exact chord margin, +1mm clear
edge_deg  = max(edge_deg_end, edge_deg_cham);
hole_span = 2 * (half_deg - edge_deg);
pitch     = num_holes > 1 ? hole_span * PI / 180 * R / (num_holes - 1) : 0;
assert(num_holes < 2 || pitch > bmr_id,
       "Holes overlap: reduce num_holes or bmr_id");

function hole_t(i) = -hole_span / 2 + (num_holes == 1 ? 0
                        : hole_span * i / (num_holes - 1));   // 0-indexed, degrees
function hole_x(i) = R * sin(hole_t(i));                      // chord x

// ---------- Shared patterns ----------
// n points equally spaced by arc length around a 2*hw x 2*hh rectangle
// centered at the origin, starting top-center, clockwise.
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

// num_bolts M3 positions on the rear rim, centered between the box's
// true outer edge and the lip's inner cutout edge -- chamfer_offset_x()
// at d = m, the same offset used to size the flat rectangle below, so
// bolts near the bottom corners land on the same centerline as
// everywhere else instead of being pushed to one edge of the band.
function rim_bolt_pts() =
    let (m = (wall_width + back_lip_width) / 2)
        [for (p = rect_pattern(num_bolts, Xe - m, height / 2 - m))
            let (z = p[1] + height / 2)
                [sign(p[0]) * min(abs(p[0]), chamfer_offset_x(m, z)), p[1]]];

// xy of the boss clocked at `ang` on the bolt circle (used by the box's
// bosses/pilot holes and the trim's flange/clearance holes)
function boss_xy(ang) = [boss_bc_d / 2 * sin(ang), boss_bc_d / 2 * cos(ang)];

// ---------- Shared cutter ----------
// Chamfered entry bore: overhang cylinder (clean cut through the entry
// face), 45-deg chamfer cone, then a straight bore. Local z = 0 at the
// entry face, increasing into the material.
module entry_bore(d, chamfer, overhang, bore_h) {
    translate([0, 0, -overhang])
        cylinder(h = overhang, d = d + 2 * chamfer);
    cylinder(h = chamfer, d1 = d + 2 * chamfer, d2 = d);
    translate([0, 0, chamfer])
        cylinder(h = bore_h, d = d);
}
