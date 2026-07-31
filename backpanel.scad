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
Xi = Xe - wall_width;

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

// ---------- Keystone jack mount ----------
// The cutout goes straight through the panel itself (panel_thick doubles
// as the keystone-rated mounting wall), so the jack -- and a patch cable
// plugged into it -- is reachable from the panel's outer (exterior)
// face. The housing extends inward from the panel into the box for the
// rest of the jack's length, ending at the punch-down terminal, which
// stays buried (wired once during assembly, same as a normal keystone
// install). The wire channels gather into a separate riser tube below
// this housing, not into it -- see the wire channels section below for
// why. Only ks_x_frac/ks_y_offset need to change to move the assembly.
ks_x       = -Xe + ks_x_frac * 2 * Xe;
ks_y       = height / 2 + ks_y_offset;
ks_outer_w = ks_body_w + 2 * ks_wall;
ks_outer_h = ks_body_h + 2 * ks_wall;

// Housing wall, from the panel's inner face inward to the punch-down end
// (ks_jack_len is measured from the panel's outer face, z = 0).
module keystone_housing() {
    translate([ks_x - ks_outer_w / 2, ks_y - ks_outer_h / 2, panel_thick])
        cube([ks_outer_w, ks_outer_h, ks_jack_len - panel_thick]);
}

// The cutout through the panel itself: the standard keystone opening
// (+ print clearance) that the jack's body slides through and its tang
// compresses through on insertion. Overhangs past both faces of the
// panel for a clean cut, rather than just touching either boundary.
module keystone_cutout() {
    cw = ks_cutout_w + ks_cutout_clearance;
    ch = ks_cutout_h + ks_cutout_clearance;
    translate([ks_x - cw / 2, ks_y - ch / 2, -1])
        cube([cw, ch, panel_thick + 2]);
}

// The cavity behind the panel: sized larger than the cutout so the
// jack's tang can flare back out after clearing the panel and catch its
// shoulder on the panel's inner face; also houses the rest of the jack
// body down to the punch-down terminal. Overlaps 1 mm into the panel so
// the cut merges cleanly with the cutout instead of just touching it.
// Sized to the real keystone hardware -- this is the jack's own
// friction-fit footprint, so it's deliberately NOT where the wire
// channels terminate; see the wire channels section for that.
module keystone_body_cavity() {
    translate([ks_x - ks_body_w / 2, ks_y - ks_body_h / 2, panel_thick - 1])
        cube([ks_body_w, ks_body_h, ks_jack_len - panel_thick + 1]);
}

// ---------- Wire channels: cable-loom bus + gathering riser ----------
// 8 bores, one insulated Cat5e conductor each (2 per box chamber). The
// governing requirement is PUSH-THREADABILITY: each channel is a single
// continuous, junction-free lumen with only gentle tangent-continuous
// sweeps (like conduit), so a strand pushed into its chamber-side entry
// hole must emerge at the riser. No sharp elbows (a pushed tip
// dead-ends into the corner wall), no shared segments or junctions
// (ambiguous exit), and no two bores ever coaxial or converging at a
// shallow angle -- merged bores mean lane-jumping for the wire, and
// their coincident curved surfaces make CGAL grind for minutes.
//
// Layout, riser outward (a wire travels it in reverse):
//   1. bus: straight horizontal bores at distinct stacked heights, all
//      running from the riser toward their chamber;
//   2. peel-off: a 90-deg in-plane arc (channel_bend_r) turning the bore
//      from horizontal to vertical at its chamber x. Peel order equals
//      stack order -- the top trace peels first -- so a peeling channel
//      never crosses a trace above it (channels farther from the riser
//      ride lower: rank-by-distance);
//   3. surfacing arc (channel_exit_r, in the y-z plane): continues from
//      vertical and curves out through the panel's inner face at ~47
//      deg, forming the angled entry hole in that channel's chamber.
// Chambers left of the riser enter it from the opposite side to those
// right of it, so the two sides reuse bus heights (stack of 6, not 8);
// opposite-side tips each stop 3mm short of the riser's center, leaving
// a gap so a reused height never produces a coaxial overlap.
// Tangent junctions (bus->peel, peel->surface) are bridged by small
// spheres with each segment pulled 0.4mm short: overlapping two
// tangent-continuous solids directly leaves a near-zero-thickness
// crescent (another CGAL grinder); a sphere crosses both transversally.
//
// The riser is its own tube below the keystone housing rather than
// feeding into keystone_body_cavity(): that cavity is the jack's own
// friction-fit footprint, with no free space once the jack is inserted.
// Wires arrive in the riser void, get pulled from its open far end,
// hand-routed to the punch-down terminal, then the riser annulus and
// terminal get sealed with silicone along with each entry hole.

// the 4 chamber x-positions; each chamber's pair of entry holes sits
// channel_pair_dx apart around its group position
channel_x_groups = [-channel_edge_frac * Xe, -channel_mid_offset,
                     channel_mid_offset, channel_edge_frac * Xe];

ch_x = [for (gi = [0:3]) for (k = [0, 1])
            channel_x_groups[gi] + (k == 0 ? -1 : 1) * channel_pair_dx / 2];

// riser sizing (needed before the per-channel derivations below)
n_heights    = 6;   // bus heights: the right side's 6 channels; the left side reuses the top 2
stack_height = n_heights * channel_d + (n_heights - 1) * channel_gap;
riser_id     = stack_height + channel_manifold_margin;
riser_od     = riser_id + 2 * channel_riser_wall;
riser_x      = ks_x;
riser_overlap = 1.5;  // into the housing bottom: deep enough that the circle-into-flat lens is wide, not a knife-edge
riser_y      = ks_y - ks_outer_h / 2 - riser_od / 2 + riser_overlap;

ch_dir  = [for (x = ch_x) x > riser_x ? 1 : -1];   // which side of the riser
ch_dist = [for (x = ch_x) abs(x - riser_x)];
n_right = len([for (d = ch_dir) if (d == 1) d]);
n_left  = len(ch_x) - n_right;

// bus height slot per channel: rank by distance within its side, the
// farthest riding lowest; the left side occupies the top n_left heights
function ch_rank(i) = len([for (j = [0:len(ch_x) - 1])
    if (ch_dir[j] == ch_dir[i] &&
        (ch_dist[j] > ch_dist[i] || (ch_dist[j] == ch_dist[i] && j < i))) j]);
function ch_slot(i) = ch_dir[i] == 1 ? ch_rank(i) : n_heights - n_left + ch_rank(i);
function transit_y(s) = riser_y - stack_height / 2 + channel_d / 2
                        + s * (channel_d + channel_gap);

// one channel: bus horizontal + peel arc + surfacing arc, sphere joints
module channel(x_term, dir, t) {
    zc  = panel_thick / 2;
    x0  = x_term - dir * channel_bend_r;      // bus end / peel arc start
    tip = riser_x + dir * 3;                  // stops 3mm short of riser center
    jg  = 0.4;                                // segment pull-back at sphere joints
    ja_bend    = jg / channel_bend_r * 180 / PI;
    ja_exit    = jg / channel_exit_r * 180 / PI;
    theta_face = acos(1 - zc / channel_exit_r);  // sweep at which the arc reaches the inner face
    // bus horizontal: riser tip -> just short of the peel arc
    hx0 = min(tip, x0 - dir * jg);
    hx1 = max(tip, x0 - dir * jg);
    translate([hx0, t, zc])
        rotate([0, 90, 0])
            cylinder(h = hx1 - hx0, d = channel_d);
    // joint sphere: bus -> peel
    translate([x0, t, zc]) sphere(d = channel_d + 0.4);
    // peel arc: horizontal to vertical, in-plane, centered above the bus end
    translate([x0, t + channel_bend_r, zc])
        rotate([0, 0, (dir > 0 ? 270 : 180) + ja_bend])
            rotate_extrude(angle = 90 - 2 * ja_bend, convexity = 2)
                translate([channel_bend_r, 0]) circle(d = channel_d);
    // joint sphere: peel -> surfacing
    translate([x_term, t + channel_bend_r, zc]) sphere(d = channel_d + 0.4);
    // surfacing arc: from vertical (+y), curving out through the inner
    // face, swept 15 deg past the face for a clean angled entry hole
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

// ---------- Accessors for backpanel_print.scad ----------
// backpanel_print.scad pulls the panel in with `use <>` (model not
// instantiated twice); these expose the derived values it needs.
function bp_Xe() = Xe;
function bp_n_channels() = len(ch_x);
function bp_channel_y(i) = transit_y(ch_slot(i));
// straight-bus x span of channel i (ascending [lo, hi]) -- a print cut
// through a channel must land inside this, well clear of both ends
function bp_channel_span(i) = ch_dir[i] == 1
    ? [riser_x + 3, ch_x[i] - channel_bend_r]
    : [ch_x[i] + channel_bend_r, riser_x - 3];
// peel + surfacing window of channel i (ascending): cuts must never land here
function bp_channel_window(i) = ch_dir[i] == 1
    ? [ch_x[i] - channel_bend_r, ch_x[i]]
    : [ch_x[i], ch_x[i] + channel_bend_r];
function bp_keystone_x() = ks_x;
function bp_keystone_halfw() = max(ks_outer_w, riser_od) / 2;

// solid wall around the riser bore, standing proud of the panel same as
// keystone_housing() (added material, must join that union)
module channel_riser_housing() {
    translate([riser_x, riser_y, panel_thick])
        cylinder(h = ks_jack_len - panel_thick, d = riser_od);
}

// the riser's hollow bore: spans from a bit below the lowest bus trace
// up to the far end (matching keystone_body_cavity()'s far end), so it's
// guaranteed to reach the punch-down area regardless of exactly where
// within the body cavity the terminal ends up
module channel_riser_bore() {
    z0 = panel_thick / 2 - channel_d / 2 - 1;
    translate([riser_x, riser_y, z0])
        cylinder(h = ks_jack_len - z0, d = riser_id);
}

// ---------- Depth / fit sanity checks ----------
// bar_depth - wall_width is the shallowest chamber depth (dead center,
// x = 0); it only gets deeper moving toward either end. Fails loudly if
// the keystone assembly is deeper than that worst case, rather than
// silently punching through into (or past) the box's baffle wall.
// ks_jack_len is already measured from the panel's own outer face, so
// it *is* the total protrusion -- no separate standoff/panel add-on.
worst_case_depth = bar_depth - wall_width;
echo(str("keystone depth = ", ks_jack_len, " mm | worst-case chamber depth (at x=0) = ",
         worst_case_depth, " mm"));
assert(ks_jack_len < worst_case_depth,
       "Keystone housing is deeper than the shallowest chamber allows -- reduce ks_jack_len, or make sure ks_x_frac keeps it away from x=0");

// The riser sits below the keystone housing; its bottom edge must clear
// the box's back-lip band (wall_width + back_lip_width) -- that's the
// box's own rim material the two parts would otherwise collide into
// when bolted together. Fails loudly rather than silently overlapping.
riser_bottom = riser_y - riser_od / 2;
safe_y_min   = wall_width + back_lip_width;
echo(str("riser od = ", riser_od, " mm | riser bottom = ", riser_bottom,
         " mm | must stay above ", safe_y_min, " mm"));
assert(riser_bottom > safe_y_min,
       "Riser doesn't fit below the keystone housing -- shrink channel_d/channel_gap/channel_manifold_margin/channel_riser_wall");

// Entry holes and their peel-arc windows must be clear of the keystone
// cutout's through-panel footprint, and inside the back-lip window.
ks_cut_half = (ks_cutout_w + ks_cutout_clearance) / 2 + 1;
lip_half_x  = Xi - back_lip_width - channel_d;
for (i = [0:len(ch_x) - 1]) {
    w_lo = min(ch_x[i], ch_x[i] - ch_dir[i] * channel_bend_r);
    w_hi = max(ch_x[i], ch_x[i] - ch_dir[i] * channel_bend_r);
    assert(w_hi < ks_x - ks_cut_half || w_lo > ks_x + ks_cut_half,
           str("Channel at x=", ch_x[i], " peels off inside the keystone cutout footprint"));
    assert(abs(ch_x[i]) < lip_half_x,
           str("Channel entry at x=", ch_x[i], " lands outside the back-lip window"));
}
assert(n_left <= n_heights - 1 && n_left <= n_right,
       "Bus height reuse assumes the left side has no more channels than the right");
// the highest entry hole must stay inside the lip window vertically
top_exit_y = transit_y(n_heights - 1) + channel_bend_r
             + channel_exit_r * sin(acos(1 - (panel_thick / 2) / channel_exit_r));
echo(str("entry holes span y ", transit_y(0) + channel_bend_r, "..", top_exit_y,
         " mm (window ", safe_y_min, "..", height - safe_y_min, ")"));
assert(top_exit_y < height - safe_y_min,
       "Top channel entry hole lands outside the back-lip window -- reduce channel_bend_r/channel_exit_r or the stack height");

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
