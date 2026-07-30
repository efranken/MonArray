// ============================================================
// Flat back panel that caps box.scad's open rear and bolts into its
// M3 heat-set inserts. Hole layout mirrors box.scad's m3_insert_holes()
// exactly (same rect_pattern, same rim_mid/hw/hh derivation) so the
// panel's holes land on the box's inserts.
// ============================================================

include <params.scad>

// ---------- Derived arc geometry (mirrors box.scad) ----------
// Only Xe (box half-length) is needed here, to size the panel and place
// its hole pattern identically to box.scad's back rim.
function f(a) = (1 - cos(a * 180 / PI)) / (2 * a);
function solve_a(t, lo, hi, i = 0) =
    i > 60 ? (lo + hi) / 2 :
    f((lo + hi) / 2) < t ? solve_a(t, (lo + hi) / 2, hi, i + 1)
                         : solve_a(t, lo, (lo + hi) / 2, i + 1);
half_angle_rad = solve_a(arc_depth / arc_length, 1e-6, PI / 2);
R  = arc_length / (2 * half_angle_rad);
Xe = R * sin(half_angle_rad * 180 / PI);

// n points equally spaced by arc length around the perimeter of a
// 2*hw x 2*hh rectangle centered at the origin (mirrors box.scad's
// rect_pattern()).
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

// ---------- Panel body ----------
// z = 0 is the outer face (screw heads land here); z increases toward
// the inner face, which butts against box.scad's back rim.
module panel_body() {
    translate([-Xe, 0, 0])
        cube([2 * Xe, height, panel_thick]);
}

// ---------- Per-hole feature ----------
// Counterbore (bp_hole_od, bp_hole_depth deep) from the outer face, then
// a clearance bore (bp_hole_id) through the remaining thickness.
module panel_hole() {
    union() {
        // clearance bore, full thickness (with overhang past both faces
        // for clean cuts) -- the counterbore below overlaps generously
        // into this rather than merely touching it, so the union isn't
        // relying on a knife-edge coincident seam at z = bp_hole_depth
        translate([0, 0, -1])
            cylinder(h = panel_thick + 2, d = bp_hole_id);
        // counterbore from the outer face
        translate([0, 0, -1])
            cylinder(h = bp_hole_depth + 1, d = bp_hole_od);
    }
}

// Same rim_mid/hw/hh derivation as box.scad's m3_insert_holes(), so the
// holes land exactly on the box's inserts.
module panel_holes() {
    rim_mid = (wall_width + back_lip_width) / 2;
    hw = Xe - rim_mid;
    hh = height / 2 - rim_mid;
    for (p = rect_pattern(num_bolts, hw, hh))
        translate([p[0], p[1] + height / 2, 0])
            panel_hole();
}

// ---------- Wire channels ----------
// One straight horizontal bore per cable (2 per box chamber = 8 total),
// embedded mid-thickness, all running to a single thru-hole (the hub)
// for pulling wires out. All 8 sit in one tightly-packed vertical stack
// centered at mid-height (not 4 independent pairs at the same height) so
// each occupies a genuinely distinct elevation -- that's also why the
// hub bore has to be sized off the stack rather than a fixed diameter:
// it must be tall enough to intersect every channel in it.
// Assumptions (adjust the params above if these don't match intent):
//   - the hub sits hub_x_frac of the way along the panel from the left
//     edge, at mid-height, and goes straight through panel_thick;
//   - "7/8 the way to the edge" and "1/8 the distance from the other
//     edge" describe mirror-symmetric points, each channel_edge_frac of
//     the half-length out from center toward its edge;
//   - "stacked vertically" -> each chamber's 2 cables get 2 adjacent
//     slots in that one shared stack.
hub_x = -Xe + hub_x_frac * 2 * Xe;

n_channels   = 8;
stack_height = n_channels * channel_d + (n_channels - 1) * channel_gap;
hub_d        = stack_height + hub_margin;   // big enough to intersect every channel in the stack

// one slot's y-center, i = 0 (bottom) .. n_channels-1 (top), centered on mid-height
function channel_y(i) =
    height / 2 - stack_height / 2 + channel_d / 2 + i * (channel_d + channel_gap);

// the 4 chamber x-positions, in the same order the stack is handed out
// (2 consecutive slots per chamber)
channel_x_groups = [-channel_edge_frac * Xe, -channel_mid_offset,
                     channel_mid_offset, channel_edge_frac * Xe];

// the 8 (x, y) far-end points: chamber i gets slots [2*i, 2*i+1]
channel_endpoints = [
    for (gi = [0:3])
        for (k = [0, 1])
            [channel_x_groups[gi], channel_y(2 * gi + k)]
];

// unit feature: a straight horizontal bore from (x, y) to the hub,
// extended `overlap` past the hub center so it merges cleanly with the
// hub bore instead of just touching it, plus a vertical breakthrough at
// the far (chamber) end so cable can be fed in from the lip side
module channel(x, y, overlap = 2) {
    dir = hub_x >= x ? 1 : -1;
    len = abs(hub_x - x) + overlap;
    translate([x, y, panel_thick / 2])
        rotate([0, dir > 0 ? 90 : -90, 0])
            cylinder(h = len, d = channel_d);
    // breakthrough on the inner (lip) face, where the channel terminates
    translate([x, y, panel_thick / 2])
        cylinder(h = panel_thick / 2 + 1, d = channel_d);
}

module wire_channels() {
    for (p = channel_endpoints)
        channel(p[0], p[1]);
}

module hub_hole() {
    translate([hub_x, height / 2, -1])
        cylinder(h = panel_thick + 2, d = hub_d);
}

module back_panel() {
    difference() {
        panel_body();
        union() {
            panel_holes();
            wire_channels();
            hub_hole();
        }
    }
}

back_panel();
