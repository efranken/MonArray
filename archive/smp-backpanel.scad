// ============================================================
// Flat cover for the box's open back: M3 bolt holes (shared rim_bolt_pts),
// a recessed RJ45 keystone mount, and 8 wire channels gathering in a
// riser below it. z=0 is the outer face; z increases toward the box.
// ============================================================

include <smp-common.scad>

// ---------- Panel body + bolt holes ----------
module panel_body() {
    translate([-Xe, 0, 0])
        cube([2 * Xe, height, panel_thick]);
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
    for (p = rim_bolt_pts())
        translate([p[0], p[1] + height / 2, 0])
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
    translate([ks_x - cw / 2, ks_y - ch / 2, -1])
        cube([cw, ch, panel_thick + 2]);
}

module keystone_body_cavity() {
    translate([ks_x - ks_body_w / 2, ks_y - ks_body_h / 2, panel_thick - 1])
        cube([ks_body_w, ks_body_h, ks_jack_len - panel_thick + 1]);
}

// ---------- Wire channels: cable-loom bus + gathering riser ----------
// Push-threadable: each of the 8 channels is a junction-free lumen --
// straight bus at its own height -> 90-deg in-plane peel arc at its
// chamber -> surfacing arc through the inner face. Peel order matches
// stack order so channels never cross; left-of-riser chambers enter from
// the opposite side and reuse the top heights (stack of 6, not 8).
// Tangent joints are bridged by spheres with segments pulled 0.4mm short
// (direct tangent overlaps leave crescents that make CGAL grind).
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

module channel(x_term, dir, t) {
    zc  = panel_thick / 2;
    x0  = x_term - dir * channel_bend_r;      // bus end / peel arc start
    tip = riser_x + dir * 3;                  // stops 3mm short of riser center
    jg  = 0.4;                                // pull-back at sphere joints
    ja_bend    = jg / channel_bend_r * 180 / PI;
    ja_exit    = jg / channel_exit_r * 180 / PI;
    theta_face = acos(1 - zc / channel_exit_r);
    // bus horizontal
    hx0 = min(tip, x0 - dir * jg);
    hx1 = max(tip, x0 - dir * jg);
    translate([hx0, t, zc])
        rotate([0, 90, 0])
            cylinder(h = hx1 - hx0, d = channel_d);
    translate([x0, t, zc]) sphere(d = channel_d + 0.4);
    // peel arc: horizontal -> vertical, in-plane
    translate([x0, t + channel_bend_r, zc])
        rotate([0, 0, (dir > 0 ? 270 : 180) + ja_bend])
            rotate_extrude(angle = 90 - 2 * ja_bend, convexity = 2)
                translate([channel_bend_r, 0]) circle(d = channel_d);
    translate([x_term, t + channel_bend_r, zc]) sphere(d = channel_d + 0.4);
    // surfacing arc: vertical -> out through the inner face (+15 deg overhang)
    translate([x_term, t + channel_bend_r, zc + channel_exit_r])
        rotate([0, 90, 0])
            rotate([0, 0, ja_exit])
                rotate_extrude(angle = theta_face + 15 - ja_exit, convexity = 2)
                    translate([channel_exit_r, 0]) circle(d = channel_d);
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
    w = ch_dir[i] == 1 ? [ch_x[i] - channel_bend_r, ch_x[i]]
                       : [ch_x[i], ch_x[i] + channel_bend_r];
    assert(w[1] < ks_x - (ks_cutout_w + ks_cutout_clearance) / 2 - 1
           || w[0] > ks_x + (ks_cutout_w + ks_cutout_clearance) / 2 + 1,
           str("Channel at x=", ch_x[i], " peels off inside the keystone cutout"));
    assert(abs(ch_x[i]) < Xi - back_lip_width - channel_d,
           str("Channel entry at x=", ch_x[i], " lands outside the back-lip window"));
}
assert(transit_y(n_heights - 1) + channel_bend_r
       + channel_exit_r * sin(acos(1 - (panel_thick / 2) / channel_exit_r))
       < height - (wall_width + back_lip_width),
       "Top channel entry hole lands outside the back-lip window");

// ---------- Accessors for backpanel_print.scad ----------
function bp_Xe() = Xe;
function bp_n_channels() = len(ch_x);
function bp_channel_y(i) = transit_y(ch_slot(i));
function bp_channel_span(i) = ch_dir[i] == 1
    ? [riser_x + 3, ch_x[i] - channel_bend_r]
    : [ch_x[i] + channel_bend_r, riser_x - 3];
function bp_channel_window(i) = ch_dir[i] == 1
    ? [ch_x[i] - channel_bend_r, ch_x[i]]
    : [ch_x[i], ch_x[i] + channel_bend_r];
function bp_keystone_x() = ks_x;
function bp_keystone_halfw() = max(ks_outer_w, riser_od) / 2;

// ---------- Assemble ----------
module back_panel() {
    difference() {
        union() {
            panel_body();
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

back_panel();
