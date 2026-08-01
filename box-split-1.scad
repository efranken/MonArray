// ============================================================
// box.scad, left piece (segment 0 of 3). Cut lands at the center of the
// left outer chamber wall's full (doubled) width -- see box.scad's
// dividers() and box_outer_wall_mid_x().
// ============================================================

segment          = 0;     // which piece this file is (0 = left, 1 = center, 2 = right)
orient_for_print = true;  // false = leave in model position (for inspecting the joints)

include <common.scad>
use <box.scad>

cut_left  = box_outer_wall_mid_x(true);
cut_right = box_outer_wall_mid_x(false);
bounds    = [-Xe, cut_left, cut_right, Xe];
n_seg     = len(bounds) - 1;
seg_lo    = bounds[segment];
seg_hi    = bounds[segment + 1];

// ---------- Sanity checks ----------
// note: the outer segments (~318mm each with the current geometry) are
// bigger than printer_bed (300mm) -- this 3-piece split is fixed at the
// wall midpoints, not chosen to fit a bed, so that's expected, not an error.
assert(cut_left < cut_right, "outer chamber walls overlap or crossed order");
echo(str("box segment ", segment, ": x ", seg_lo, " .. ", seg_hi, "  (", seg_hi - seg_lo, " mm)"));
// both cuts must clear every BMR bore (bosses sit inside the bore's
// x-span, so clearing the bore clears them too)
for (c = [cut_left, cut_right], i = [0:num_holes - 1])
    assert(abs(c - box_hole_x(i)) > bmr_od / 2 + 2,
           str("Box cut at x=", c, " slices BMR bore ", i + 1));

module box_segment(s) {
    intersection() {
        arched_hole_bar();
        translate([bounds[s], -height, -10])
            cube([bounds[s + 1] - bounds[s], 2 * height, bar_depth + rear_end_depth + 40]);
    }
}

// stand the segment on its cut face; end segments stand on their closed
// end wall instead (cut face up), matching archive/box_print.scad
if (orient_for_print) {
    if (segment == 0)
        translate([0, 0, -seg_lo]) rotate([0, -90, 0]) box_segment(segment);
    else
        translate([0, 0, seg_hi]) rotate([0, 90, 0]) box_segment(segment);
} else {
    box_segment(segment);
}
