// ============================================================
// Shared geometry for box / backpanel / trim.
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

// ---------- BMR hole layout along the arc ----------
// First/last hole edges sit end_space from the ends; centers fill the
// remaining span equidistantly.
edge_deg  = (end_space + bmr_id / 2) / R * 180 / PI;
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
