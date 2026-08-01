// ============================================================
// Print-ready segment of box.scad for a 300mm-class printer.
// Set `segment` (0 = leftmost .. 3 = rightmost) and export each.
//
// Cuts come from box_cut_after_hole (params.scad): each lands in the
// gap after that hole -- at the gap midpoint, or at the divider's face
// when the gap carries a divider, so that joint mates against the
// divider as a full bulkhead (gluing it also seals the chamber).
//
// Each joint face gets 4 filament-dowel holes (joint_pin_d), all in the
// solid top/bottom caps -- NOT in the arc-face wall: the wall is only
// ~4-5mm thick and its outer surface slopes ~1mm across a pin's length
// near the outer cuts, which thins the cover over the hole to nothing.
//
// Print orientation (applied when orient_for_print = true): standing on
// the cut face, so every wall is vertical (arc face leans <= ~15deg),
// BMR bores become holes in a vertical wall, and no supports are
// needed. End segments stand on their closed end wall instead.
// ============================================================

segment          = 0;     // [0:3] which piece to render/export
orient_for_print = true;  // false = leave in model position (for inspecting the joints)

include <params.scad>
use <box.scad>

cuts   = [for (h = box_cut_after_hole) box_gap_cut_x(h)];
Xe_p   = box_Xe();
bounds = concat([-Xe_p], cuts, [Xe_p]);
n_seg  = len(bounds) - 1;
seg_lo = bounds[segment];
seg_hi = bounds[segment + 1];

// ---------- Sanity checks ----------
for (i = [0:len(cuts) - 2])
    assert(cuts[i] < cuts[i + 1], "box_cut_after_hole must be ascending");
for (s = [0:n_seg - 1]) {
    L = bounds[s + 1] - bounds[s];
    echo(str("box segment ", s, ": x ", bounds[s], " .. ", bounds[s + 1],
             "  (", L, " mm)"));
    assert(L <= printer_bed,
           str("Box segment ", s, " is ", L, " mm -- exceeds printer_bed"));
}
// every cut must clear every BMR bore (bosses sit inside the bore's
// x-span, so clearing the bore clears them too)
for (c = cuts, i = [0:num_holes - 1])
    assert(abs(c - box_hole_x(i)) > bmr_od / 2 + 2,
           str("Box cut at x=", c, " slices BMR bore ", i + 1));
// ...and every M3 insert hole around the rear rim
rim_mid_p = (wall_width + back_lip_width) / 2;
for (c = cuts, p = rect_pattern(num_bolts, Xe_p - rim_mid_p, height / 2 - rim_mid_p))
    assert(abs(c - p[0]) > m3_ins_od / 2 + boss_chamfer + joint_pin_d + 2,
           str("Box cut at x=", c, " lands on the M3 insert at x=", p[0]));

// ---------- Joint features ----------
// 4 filament-dowel holes per joint, in the caps (final-part coords:
// caps occupy y = +-(height/2 - wall_width .. height/2), solid across
// the full depth z = 0 .. arc face)
function pin_pts(c) = [for (yy = [height / 2 - 2, -(height / 2 - 2)],
                            zz = [30, 55]) [c, yy, zz]];

module joint_pin_holes() {
    for (c = cuts, p = pin_pts(c))
        translate([p[0] - joint_pin_len / 2, p[1], p[2]])
            rotate([0, 90, 0])
                cylinder(h = joint_pin_len, d = joint_pin_d);
}

// pin holes are cut from the FULL model before slabbing, so both mating
// segments automatically get mirror-image halves of every hole
module box_full() {
    difference() {
        arched_hole_bar();
        joint_pin_holes();
    }
}

module box_segment(s) {
    intersection() {
        box_full();
        translate([bounds[s], -height, -10])
            cube([bounds[s + 1] - bounds[s], 2 * height,
                  bar_depth + arc_depth + 40]);
    }
}

// stand the segment on its cut face; end segments stand on their closed
// end wall (cut face up) so the end cap prints on the bed, not as a roof
if (orient_for_print) {
    if (segment == 0)
        translate([0, 0, -seg_lo]) rotate([0, -90, 0]) box_segment(segment);
    else
        translate([0, 0, seg_hi]) rotate([0, 90, 0]) box_segment(segment);
} else {
    box_segment(segment);
}
