// ============================================================
// Print-ready segment of backpanel.scad for a 300mm-class printer.
// Set `segment` (0 = leftmost .. 3 = rightmost) and export each.
//
// Cuts come from panel_cuts (params.scad); they are staggered off the
// box's cuts so the bolted panel bridges every box joint (and vice
// versa) and no seams line up. Asserts below verify each cut only
// crosses wire channels in their straight bus region -- never a peel
// or surfacing arc -- and stays clear of the keystone/riser zone and
// the panel's bolt holes.
//
// Joint features, cut from the full model before slabbing so both
// mating segments get mirror halves automatically:
//   - 2 filament-dowel holes per joint (joint_pin_d), placed in the
//     y-bands clear of the channel loom;
//   - a funnel (joint_funnel_d/joint_funnel_len bicone) on every wire
//     channel where it crosses a seam, so a pushed strand gets guided
//     over any small registration step instead of snagging on it.
//
// Print orientation: already ideal as modeled -- flat, outer face
// (z = 0) on the bed, keystone housing and riser rising as vertical
// walls, channels printing as short internal bridges. No supports.
// ============================================================

segment = 0;  // [0:3] which piece to render/export

include <params.scad>
use <backpanel.scad>

Xe_p   = bp_Xe();
bounds = concat([-Xe_p], panel_cuts, [Xe_p]);
n_seg  = len(bounds) - 1;

// ---------- Sanity checks ----------
for (i = [0:len(panel_cuts) - 2])
    assert(panel_cuts[i] < panel_cuts[i + 1], "panel_cuts must be ascending");
for (s = [0:n_seg - 1]) {
    L = bounds[s + 1] - bounds[s];
    echo(str("panel segment ", s, ": x ", bounds[s], " .. ", bounds[s + 1],
             "  (", L, " mm)"));
    assert(L <= printer_bed,
           str("Panel segment ", s, " is ", L, " mm -- exceeds printer_bed"));
}
for (c = panel_cuts) {
    // keystone housing + riser zone
    assert(abs(c - bp_keystone_x()) > bp_keystone_halfw() + 3,
           str("Panel cut at x=", c, " hits the keystone/riser zone"));
    // bolt holes
    rim_mid_p = (wall_width + back_lip_width) / 2;
    for (p = rect_pattern(num_bolts, Xe_p - rim_mid_p, height / 2 - rim_mid_p))
        assert(abs(c - p[0]) > bp_hole_od / 2 + 3,
               str("Panel cut at x=", c, " lands on the bolt hole at x=", p[0]));
    // channels: each is either crossed cleanly mid-bus (with room for the
    // funnel) or missed entirely -- never grazed, never cut in an arc
    for (i = [0:bp_n_channels() - 1]) {
        sp = bp_channel_span(i);
        w  = bp_channel_window(i);
        assert(c < w[0] - 2 || c > w[1] + 2,
               str("Panel cut at x=", c, " slices channel ", i,
                   "'s peel/surfacing arc (window ", w, ")"));
        assert((c > sp[0] + joint_funnel_len + 2 && c < sp[1] - joint_funnel_len - 2)
               || c < sp[0] - 2 || c > sp[1] + 2,
               str("Panel cut at x=", c, " grazes the end of channel ", i,
                   "'s bus span ", sp));
    }
}

// does channel i cross cut c?
function crosses(i, c) =
    let (sp = bp_channel_span(i)) c > sp[0] && c < sp[1];

// ---------- Joint features ----------
module joint_pin_holes() {
    for (c = panel_cuts, yy = [8, 58])
        translate([c - joint_pin_len / 2, yy, panel_thick / 2])
            rotate([0, 90, 0])
                cylinder(h = joint_pin_len, d = joint_pin_d);
}

// bicone widening each crossed channel to joint_funnel_d right at the
// seam, tapering back to (just under) bore diameter over
// joint_funnel_len on each side -- the narrow ends sit 0.2 under
// channel_d so the cones overlap the bore as a wedge instead of
// meeting it in a tangent circle
module joint_funnels() {
    for (c = panel_cuts, i = [0:bp_n_channels() - 1])
        if (crosses(i, c))
            translate([c, bp_channel_y(i), panel_thick / 2])
                rotate([0, 90, 0]) {
                    cylinder(h = joint_funnel_len, d1 = joint_funnel_d,
                             d2 = channel_d - 0.2);
                    rotate([0, 180, 0])
                        cylinder(h = joint_funnel_len, d1 = joint_funnel_d,
                                 d2 = channel_d - 0.2);
                }
}

module panel_full() {
    difference() {
        back_panel();
        joint_pin_holes();
        joint_funnels();
    }
}

module panel_segment(s) {
    intersection() {
        panel_full();
        translate([bounds[s], -1, -1])
            cube([bounds[s + 1] - bounds[s], height + 2, ks_jack_len + 2]);
    }
}

panel_segment(segment);
