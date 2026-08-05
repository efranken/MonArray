// ============================================================
// Cover for the box's open back, in 3 pieces to match its "\_/" bend.
// Built as ONE flat assembly first -- body, bolt holes, keystone mount,
// wire channels, all in the ORIGINAL flat (x, y=height, z=depth) frame
// -- then cut into 3 strips and folded: the two end strips rotate about
// their seam with the flat center piece, by the angle the box's own
// rear_segments have there; the center strip is unrotated (a 0-degree
// fold is a no-op). This keeps the keystone/wire-channel geometry
// (already complex, with its own fit asserts) entirely unchanged --
// only the flat assembly's overall shape and the bolt-hole positions
// need to account for the bend, not every feature individually.
// Per piece, z=0 is that piece's own outer face; z increases toward the
// box (that's local to each piece post-fold, not global).
// ============================================================

include <common.scad>
use <box.scad>

seam_gap = 0.5;   // total gap at each internal seam, split evenly between the two adjoining pieces
n_pieces = box_num_rear_segments();

// The break points (shared corners between adjoining rear_segments) and
// each end segment's true 3D length, vs. its flat x-span -- the flat
// assembly needs to be LONGER than 2*Xe by that difference, so that
// after folding, the end pieces still reach the box's true corners
// instead of falling short (a segment's 3D length is always >= its own
// x-span, once it's not perfectly flat).
break_lo = box_rear_segment(0)[1][0];
break_hi = box_rear_segment(n_pieces - 1)[0][0];
len0     = norm(box_rear_segment(0)[1] - box_rear_segment(0)[0]);
len_last = norm(box_rear_segment(n_pieces - 1)[1] - box_rear_segment(n_pieces - 1)[0]);
extra_left  = len0 - (break_lo + Xe);
extra_right = len_last - (Xe - break_hi);

// x in the flat (pre-fold) frame for a point at distance local_x along
// rear_segments[seg_index], measured from that segment's own [0] point
// -- see box_rim_bolt_frame()'s seg_index/local_x. Segment 0's hinge is
// its FAR end (local_x = len0, at break_lo); the last segment's hinge is
// its NEAR end (local_x = 0, at break_hi) -- flat x runs outward from
// the hinge in both cases, away from the flat center.
function flat_x(seg_index, local_x) =
    seg_index == 0 ? break_lo - len0 + local_x :
    seg_index == n_pieces - 1 ? break_hi + local_x :
    box_rear_segment(seg_index)[0][0] + local_x;

// Rotates children() about the line x=hinge_x, z=hinge_z (y, the height
// axis, unaffected) by ang -- verified algebraically (not just
// empirically) against box_rear_segment(0)/(n-1): folding the flat
// piece's far corner about its own hinge by that segment's own
// box_rear_angle() lands it exactly on the box's true corner.
module rotate_about_x(hinge_x, hinge_z, ang) {
    translate([hinge_x, 0, hinge_z])
        rotate([0, -ang, 0])
            translate([-hinge_x, 0, -hinge_z])
                children();
}

// ---------- Flat body + bolt holes ----------
module flat_panel_body() {
    translate([-Xe - extra_left, 0, 0])
        cube([2 * Xe + extra_left + extra_right, height, panel_thick]);
}

// counterbore from the outer face + through clearance bore; the
// counterbore overlaps generously into the bore rather than meeting it
// at a knife-edge coincident seam
module panel_hole() {
    translate([0, 0, -1])
        cylinder(h = panel_thick + 2, d = bp_hole_id);
    translate([0, 0, -1])
        cylinder(h = bp_hole_depth + 1, d = bp_hole_od);
}

module panel_holes() {
    for (i = [0:box_rim_bolt_count() - 1])
        let (f = box_rim_bolt_frame(i))   // f = [x,y,z,angle_deg,seg_index,local_x]
            translate([flat_x(f[4], f[5]), f[2], 0])
                panel_hole();
}

// ---------- Keystone jack mount ----------
// Cutout goes through the panel (panel_thick is the mounting wall); the
// housing extends inward to the punch-down terminal. keystone_body_cavity()
// is the jack's own friction-fit footprint -- wires gather in the riser
// below instead, since there's no room there once the jack is inserted.
ks_x       = -Xe + ks_x_frac * 2 * Xe;
ks_y       = height / 2 + ks_y_offset;
ks_outer_w = ks_body_w + 2 * ks_wall;
ks_outer_h = ks_body_h + 2 * ks_wall;

module keystone_housing() {
    translate([ks_x - ks_outer_w / 2, ks_y - ks_outer_h / 2, panel_thick])
        cube([ks_outer_w, ks_outer_h, ks_jack_len - panel_thick]);
}

module keystone_cutout() {
    cw = ks_cutout_w + ks_cutout_clearance;
    ch = ks_cutout_h + ks_cutout_clearance;
    body_bottom = ks_y - ks_body_h / 2;
    translate([ks_x - cw / 2, body_bottom + ks_cutout_y_offset, -1])
        cube([cw, ch, panel_thick + 2]);
}

module keystone_body_cavity() {
    translate([ks_x - ks_body_w / 2, ks_y - ks_body_h / 2, panel_thick - 1])
        cube([ks_body_w, ks_body_h, ks_jack_len - panel_thick + 1]);
}

// ---------- Wire channels: cable-loom bus + gathering riser ----------
// Push-threadable: each of the 8 channels is a junction-free lumen --
// straight bus at its own height, then one straight funnel dive (equal
// x/y/z reach, so a true 45 degrees both in-plane and through the panel
// face) out to an oversized mouth at the chamber. Peel order matches
// stack order so channels never cross; left-of-riser chambers enter from
// the opposite side and reuse the top heights (stack of 6, not 8).
channel_x_groups = [-channel_edge_frac * Xe, -channel_mid_offset,
                     channel_mid_offset, channel_edge_frac * Xe];

ch_x = [for (gi = [0:3]) for (k = [0, 1])
            channel_x_groups[gi] + (k == 0 ? -1 : 1) * channel_pair_dx / 2];

n_heights     = 6;
stack_height  = n_heights * channel_d + (n_heights - 1) * channel_gap;
riser_id      = stack_height + channel_manifold_margin;
riser_od      = riser_id + 2 * channel_riser_wall;
riser_x       = ks_x;
riser_overlap = 1.5;  // into the housing: deep enough that the circle-into-flat lens is wide
riser_y       = ks_y - ks_outer_h / 2 - riser_od / 2 + riser_overlap;

ch_dir  = [for (x = ch_x) x > riser_x ? 1 : -1];
ch_dist = [for (x = ch_x) abs(x - riser_x)];
n_right = len([for (d = ch_dir) if (d == 1) d]);
n_left  = len(ch_x) - n_right;

function ch_rank(i) = len([for (j = [0:len(ch_x) - 1])
    if (ch_dir[j] == ch_dir[i] &&
        (ch_dist[j] > ch_dist[i] || (ch_dist[j] == ch_dist[i] && j < i))) j]);
function ch_slot(i) = ch_dir[i] == 1 ? ch_rank(i) : n_heights - n_left + ch_rank(i);
function transit_y(s) = riser_y - stack_height / 2 + channel_d / 2
                        + s * (channel_d + channel_gap);

// x/y/z reach of the funnel dive: sized off panel_thick so the mouth
// always actually clears the inner face (not a free-standing tunable --
// see channel_face_overshoot in params.scad).
channel_run = panel_thick / 2 + channel_face_overshoot;

module channel(x_term, dir, t) {
    zc = panel_thick / 2;
    x0 = x_term - dir * channel_run;   // bus end / funnel start
    tip = riser_x + dir * 3;           // stops 3mm short of riser center
    ov = 0.4;                          // bus pull-back, bridged by the funnel's start sphere
    hx0 = min(tip, x0 - dir * ov);
    hx1 = max(tip, x0 - dir * ov);
    // bus: straight run at this wire's stacked height, out to channel_run
    // short of the chamber -- this is the part that threads perfectly
    translate([hx0, t, zc])
        rotate([0, 90, 0])
            cylinder(h = hx1 - hx0, d = channel_d);
    // funnel: one straight taper from the bus's ID to a
    // channel_funnel_mult-times-wider mouth, channel_face_overshoot past
    // the inner face. hull() of two spheres is inherently a clean convex
    // taper (no tangent-joint crescents to worry about, unlike the arcs
    // this replaced).
    hull() {
        translate([x0, t, zc])
            sphere(d = channel_d);
        translate([x_term, t + channel_run, zc + channel_run])
            sphere(d = channel_d * channel_funnel_mult);
    }
}

module wire_channels() {
    for (i = [0:len(ch_x) - 1])
        channel(ch_x[i], ch_dir[i], transit_y(ch_slot(i)));
}

module channel_riser_housing() {
    translate([riser_x, riser_y, panel_thick])
        cylinder(h = ks_jack_len - panel_thick, d = riser_od);
}

module channel_riser_bore() {
    z0 = panel_thick / 2 - channel_d / 2 - 1;
    translate([riser_x, riser_y, z0])
        cylinder(h = ks_jack_len - z0, d = riser_id);
}

// ---------- Fit checks ----------
assert(ks_jack_len < bar_depth - wall_width,
       "Keystone housing deeper than the shallowest chamber -- reduce ks_jack_len");
assert(riser_y - riser_od / 2 > wall_width + back_lip_width,
       "Riser collides with the box's back-lip band -- shrink the channel stack");
assert(n_left <= n_heights - 1 && n_left <= n_right,
       "Bus height reuse assumes the left side has no more channels than the right");
for (i = [0:len(ch_x) - 1]) {
    w = ch_dir[i] == 1 ? [ch_x[i] - channel_run, ch_x[i]]
                       : [ch_x[i], ch_x[i] + channel_run];
    assert(w[1] < ks_x - (ks_cutout_w + ks_cutout_clearance) / 2 - 1
           || w[0] > ks_x + (ks_cutout_w + ks_cutout_clearance) / 2 + 1,
           str("Channel at x=", ch_x[i], " peels off inside the keystone cutout"));
    assert(abs(ch_x[i]) < Xi - back_lip_width - channel_d,
           str("Channel entry at x=", ch_x[i], " lands outside the back-lip window"));
}
assert(transit_y(n_heights - 1) + channel_run
       < height - (wall_width + back_lip_width),
       "Top channel entry hole lands outside the back-lip window");
// the flat-assembly extension for folding must not eat into channel/
// keystone territory -- it shouldn't, since extra_left/right are only
// ever needed near the very tips, but confirm rather than assume
assert(-Xe - extra_left < channel_x_groups[0] - channel_run,
       "Left flat-assembly extension overlaps the outer channel pair");
assert(Xe + extra_right > channel_x_groups[3] + channel_run,
       "Right flat-assembly extension doesn't clear the outer channel pair");

// ---------- Accessors for backpanel_print.scad ----------
function bp_Xe() = Xe;
function bp_n_channels() = len(ch_x);
function bp_channel_y(i) = transit_y(ch_slot(i));
function bp_channel_span(i) = ch_dir[i] == 1
    ? [riser_x + 3, ch_x[i] - channel_run]
    : [ch_x[i] + channel_run, riser_x - 3];
function bp_channel_window(i) = ch_dir[i] == 1
    ? [ch_x[i] - channel_run, ch_x[i]]
    : [ch_x[i], ch_x[i] + channel_run];
function bp_keystone_x() = ks_x;
function bp_keystone_halfw() = max(ks_outer_w, riser_od) / 2;

// ---------- Assemble ----------
module flat_full_assembly() {
    difference() {
        union() {
            flat_panel_body();
            keystone_housing();
            channel_riser_housing();
        }
        union() {
            panel_holes();
            wire_channels();
            channel_riser_bore();
            keystone_cutout();
            keystone_body_cavity();
        }
    }
}

// x-only clip: y/z margins just need to clear every feature (the
// keystone housing and channel riser reach z = ks_jack_len, well past
// panel_thick), not just the flat panel body itself.
module clip_x(x_lo, x_hi) {
    z_span = max(panel_thick, ks_jack_len) + 20;
    intersection() {
        children();
        translate([x_lo, -10, -10])
            cube([x_hi - x_lo, height + 20, z_span]);
    }
}

// margin so two flat cuts at different fold angles still clear each
// other by seam_gap everywhere through panel_thick, not just at one
// face -- see box.scad/CLAUDE.md for the same tradeoff worked out
// for back_lip(); negligible at the near-flat default.
function seam_margin(i, j) = panel_thick * abs(tan(box_rear_angle(j) - box_rear_angle(i)));

module panel_piece(i) {
    trim_lo = i == 0 ? 0 : seam_gap / 2 + seam_margin(i - 1, i);
    trim_hi = i == n_pieces - 1 ? 0 : seam_gap / 2 + seam_margin(i, i + 1);
    x_lo = (i == 0 ? -Xe - extra_left : box_rear_segment(i)[0][0]) + trim_lo;
    x_hi = (i == n_pieces - 1 ? Xe + extra_right : box_rear_segment(i)[1][0]) - trim_hi;
    if (i == 0)
        rotate_about_x(break_lo, 0, box_rear_angle(0))
            clip_x(x_lo, x_hi) flat_full_assembly();
    else if (i == n_pieces - 1)
        rotate_about_x(break_hi, 0, box_rear_angle(n_pieces - 1))
            clip_x(x_lo, x_hi) flat_full_assembly();
    else
        clip_x(x_lo, x_hi) flat_full_assembly();
}

module back_panel() {
    for (i = [0:n_pieces - 1])
        panel_piece(i);
}

back_panel();
