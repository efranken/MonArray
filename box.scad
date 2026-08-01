// ============================================================
// Arched speaker bar: concave-arc profile, shelled hollow with an open
// back + seating lip, BMR cutouts, trim bosses, dividers, M3 rim inserts.
// ============================================================

include <common.scad>

// ---------- Profile: concave arc top, "/-\" rear shaped around the center chamber ----------
// Rear face is flat (y=0, full depth) only across the center chamber --
// between the two dividers that bound it -- then angles forward to
// rear_end_depth at each box end. Break points are the outer edges of
// those two dividers, so the slope starts exactly where the center
// chamber's own walls do and ends at the box edges.
assert(len(divider_after_hole) > 0,
       "the '/-\\' rear shape needs at least one divider to define the center chamber's outer walls");
rear_break_h_lo = min(divider_after_hole);
rear_break_h_hi = max(divider_after_hole);
rear_break_x_lo = R * sin((hole_t(rear_break_h_lo - 1) + hole_t(rear_break_h_lo)) / 2) - divider_thickness / 2;
rear_break_x_hi = R * sin((hole_t(rear_break_h_hi - 1) + hole_t(rear_break_h_hi)) / 2) + divider_thickness / 2;
rear_end_y = Yc - sqrt(R * R - Xe * Xe) - rear_end_depth;   // rear-face y at x = +-Xe

// The rear boundary as 3 straight segments, in order left to right --
// the single source every rear-facing feature below (the open-back
// offset, the rear-cut poke-through, back_lip()) is driven from, so
// they can't drift out of sync with each other or with profile_2d().
rear_segments = [
    [[-Xe, rear_end_y], [rear_break_x_lo, 0]],
    [[rear_break_x_lo, 0], [rear_break_x_hi, 0]],
    [[rear_break_x_hi, 0], [Xe, rear_end_y]]
];

// Angle of rear_segments[i], and the local frame at its start point:
// local x runs along the segment toward its end, local y is
// perpendicular, into the material. The single source every rear-facing
// feature (below, and backpanel.scad's fold) reads this from,
// instead of each re-deriving atan2() on its own.
function rear_seg_angle(i) =
    let (seg = rear_segments[i])
        atan2(seg[1][1] - seg[0][1], seg[1][0] - seg[0][0]);

module segment_frame(i) {
    translate([rear_segments[i][0][0], rear_segments[i][0][1], 0])
        rotate([0, 0, rear_seg_angle(i)])
            children();
}

module profile_2d() {
    n = 64;
    polygon(concat(
        [for (i = [0:n]) let (t = -half_deg + 2 * half_deg * i / n)
            [R * sin(t), Yc - R * cos(t)]],
        [[Xe, rear_end_y], [rear_break_x_hi, 0], [rear_break_x_lo, 0], [-Xe, rear_end_y]]));
}

// ---------- Per-hole placement ----------
// One local frame per BMR hole, shared by the cutout, bosses, and
// pilot holes: z runs along the hole axis into the cavity, origin at
// the outer arc surface, facet plane at z = wall_width.
module per_hole_frame() {
    for (i = [0:num_holes - 1])
        translate([0, Yc, 0])
            rotate([0, 0, hole_t(i)])
                translate([0, -R, height / 2])
                    rotate([90, 0, 0])
                        children();
}

// Stepped BMR cutout: ONE solid of revolution (bmr_id for the first
// baffle_space, bmr_od beyond), not a union of two cylinders -- the
// union's internal seam silently corrupts STL export (see CLAUDE.md).
module stepped_cutter() {
    $fn = bmr_fn;               // the one feature worth spending facets on
    od_depth = wall_width + 8;  // reach well past the faceted wall
    rotate_extrude(convexity = 4)
        polygon([[0, -2], [bmr_id / 2, -2], [bmr_id / 2, baffle_space],
                 [bmr_od / 2, baffle_space], [bmr_od / 2, od_depth], [0, od_depth]]);
}

// ---------- Faceted shell cavity ----------
// Two boundary kinds, combined: the arc side is one hand-derived flat
// facet per hole (tangent to the inner arc, perpendicular to the hole
// axis, wall_width thick at the hole center); the rear+ends are a
// generic offset() of profile_2d()'s lower portion, so the cavity reacts
// automatically if that shape changes -- including the "/-\" rear shape
// above. They meet at cap_y, a margin below the lowest facet point; the
// assert below catches the rear shape (or any future rear-end feature)
// growing taller than cap_y instead of silently corrupting the cavity.
function facet_end(t, x0) =            // tangent line at angle t meets vertical x = x0
    let (s = (x0 - d_in * sin(t)) / cos(t))
        [x0, Yc - d_in * cos(t) + s * sin(t)];

facet_pts = concat(
    [facet_end(hole_t(0), -Xi)],
    [for (i = [0:num_holes - 2])
        let (tm = (hole_t(i) + hole_t(i + 1)) / 2,
             dt = (hole_t(i + 1) - hole_t(i)) / 2,
             r  = d_in / cos(dt))
            [r * sin(tm), Yc - r * cos(tm)]],
    [facet_end(hole_t(num_holes - 1), Xi)]);
cap_y = min([for (p = facet_pts) p[1]]) - 5;   // 5mm clear margin below the lowest facet point

assert(cap_y > wall_width,
       "cap_y is too low -- a rear-end feature (e.g. a chamfer) likely reaches above it; raise its margin or lower it explicitly");
// outer_cap_2d() clips profile_2d() at cap_y + wall_width + 15 before
// offsetting -- that clip height, not cap_y itself, is what must clear
// the "\_/" rear shape's peak (rear_end_y, at x = +-Xe) or the corner
// gets truncated before the offset ever sees it.
assert(cap_y + wall_width + 15 > rear_end_y + 5,
       "rear_end_depth's peak is too close to the arc-side facet clip -- reduce rear_end_depth or increase end_space/reduce num_holes");

// arc-side facets, capped below by a flat edge at cap_y (inset Xi, same
// as the facets -- valid since cap_y sits above any rear-corner feature)
module facet_cap_2d() {
    polygon(concat(facet_pts, [[Xi, cap_y], [-Xi, cap_y]]));
}

// profile_2d()'s rear+ends portion, clipped past cap_y with enough
// margin that the -wall_width offset below still clears it by 5mm.
module outer_cap_2d() {
    intersection() {
        profile_2d();
        translate([-Xe - 10, -10, 0])
            square([2 * (Xe + 10), cap_y + wall_width + 15]);   // top edge at cap_y + wall_width + 5
    }
}

// offset() would also inset all 3 rear segments, which must stay flush
// (each one is a genuine opening, not a wall -- see back_lip() below).
// Fix: union in a plain oversized rectangle hugging each segment's
// outward side before offsetting, so there's solid material well past
// that edge and offset() has nothing there to inset; re-intersect with
// the un-bloated outer_cap_2d() afterward to discard the rectangles'
// spillover outside the real profile. (An earlier version mirrored the
// *whole* outer_cap_2d() shape across each segment's line instead -- that
// dragged the far-away arc boundary along too, which isn't mirror-
// symmetric across a rear segment's line, and left an uncancelled wedge
// of material right at the two true outer corners where a rear segment
// meets the arc.)
module outer_cap_open_2d() {
    margin = 50;  // past both ends, comfortably past any segment's own length
    intersection() {
        offset(delta = -wall_width, chamfer = false)
            union() {
                outer_cap_2d();
                for (i = [0:len(rear_segments) - 1])
                    let (seg = rear_segments[i])
                        segment_frame(i)
                            translate([-margin, -(wall_width + margin), 0])
                                square([norm(seg[1] - seg[0]) + 2 * margin, wall_width + margin]);
                // the strips above only bloat outward along each segment's
                // own edge; at the 2 true outer corners (rear meets the
                // arc, not another rear segment) that leaves the corner
                // vertex itself uncovered on the arc side, so offset()
                // still insets a sliver there -- patch with a disc
                // centered on each true corner, covering every direction.
                translate(rear_segments[0][0]) circle(r = 3 * wall_width);
                translate(rear_segments[len(rear_segments) - 1][1]) circle(r = 3 * wall_width);
            }
        outer_cap_2d();
    }
}

module cavity_2d() {
    union() {
        outer_cap_open_2d();
        facet_cap_2d();
    }
}

// rear_cut = false: flush at the rear boundary, for clipping additive
// features so they never protrude past it. rear_cut = true: each of the
// 3 rear segments extended 1mm past its own true surface (cutting flush
// against a coincident face risks a degenerate boundary).
module shell_cavity(rear_cut = false) {
    translate([0, 0, wall_width])
        linear_extrude(height - 2 * wall_width, convexity = 10)
            cavity_2d();
    if (rear_cut)
        for (i = [0:len(rear_segments) - 1])
            let (seg = rear_segments[i])
                segment_frame(i)
                    translate([-1, -1, wall_width])
                        cube([norm(seg[1] - seg[0]) + 2, 1, height - 2 * wall_width]);
}

// ---------- Dividers between selected hole pairs ----------
// Slabs at the chord midpoints, clipped to the cavity in ONE
// intersection so the expensive faceted extrude is evaluated once. The
// two outer chamber walls (first/last entries in divider_after_hole --
// the ones bounding the outer chambers, not the interior ones splitting
// chambers that are already inner) are double thickness, with the extra
// divider_thickness added on the outer side only: their center-facing
// face stays exactly where a normal divider's would be, so only the
// outer-chamber side of the wall grows.
module dividers() {
    n = len(divider_after_hole);
    intersection() {
        union() {
            for (i = [0:n - 1])
                let (h = divider_after_hole[i],
                     mid = R * sin((hole_t(h - 1) + hole_t(h)) / 2),
                     outer_left  = (i == 0),
                     outer_right = (i == n - 1),
                     extra = (outer_left || outer_right) ? divider_thickness : 0,
                     x0 = mid - divider_thickness / 2 - (outer_left ? extra : 0))
                    translate([x0, -1, -1])
                        cube([divider_thickness + extra, bar_depth + arc_depth + 2, height + 2]);
        }
        shell_cavity();
    }
}

// ---------- Seating lip around the open back ----------
// Picture-frame rim, back_lip_width wide, back_lip_depth deep, for the
// backpanel sections to seat against, spanning the whole bent back:
// top and bottom rails run continuously across all 3 rear_segments
// (each segment's own local frame tilts its own piece to match, and
// consecutive segments share an endpoint so the rails join cleanly at
// the break points), but end caps -- the frame's left/right sides --
// only exist at the two true box corners. No end cap sits at an
// internal break point, since that's where a divider already is; a cap
// there would straddle it and collide with it for no reason (the
// divider already does that job).
module rail_band(z0, z_h) {
    eps = 0.1;
    for (i = [0:len(rear_segments) - 1])
        let (seg = rear_segments[i])
            segment_frame(i)
                translate([0, 0, z0])
                    cube([norm(seg[1] - seg[0]), back_lip_depth + eps, z_h]);
}

module end_cap(i, at_start) {
    eps = 0.1;
    len = norm(rear_segments[i][1] - rear_segments[i][0]);
    segment_frame(i)
        translate([at_start ? 0 : len - back_lip_width, 0, wall_width])
            cube([back_lip_width, back_lip_depth + eps, height - 2 * wall_width]);
}

module back_lip() {
    n = len(rear_segments);
    union() {
        rail_band(wall_width, back_lip_width);
        rail_band(height - wall_width - back_lip_width, back_lip_width);
        end_cap(0, true);
        end_cap(n - 1, false);
    }
}

// ---------- M3 heat-set insert holes around the rear rim ----------
// num_bolts positions on the rear rim, centered in the wall+lip band --
// same (x,z) parameter rectangle rim_bolt_pts() always used
// (rect_pattern(num_bolts, Xe - m, height/2 - m)), but each point's x
// now picks which of the 3 rear_segments it lands on and drills
// perpendicular to THAT segment's local surface (via segment_frame())
// instead of assuming the flat y=0 rear that no longer spans the ends.
// Shared with backpanel.scad via box_rim_bolt_frame() below, so the
// box's inserts and the panel's clearance holes can't drift apart.
function rim_bolt_segment_index(x) =
    x <= rear_break_x_lo ? 0 : x <= rear_break_x_hi ? 1 : 2;

function box_rim_bolt_count() = num_bolts;

// [x, y, z, angle_deg, seg_index, local_x] for rim bolt i, in box (pre-
// rotation) coords -- angle_deg is the z-axis rotation segment_frame()
// would apply for this bolt's segment, and local_x is its distance along
// that segment from rear_segments[seg_index][0], so a caller can align a
// driller/panel-hole with it directly (globally via x/y/z/angle_deg, or
// in that segment's own local frame via seg_index/local_x) instead of
// re-deriving which segment it's on.
function box_rim_bolt_frame(i) =
    let (m = (wall_width + back_lip_width) / 2,
         p = rect_pattern(num_bolts, Xe - m, height / 2 - m)[i],
         si = rim_bolt_segment_index(p[0]),
         seg = rear_segments[si],
         seg_len = norm(seg[1] - seg[0]),
         t = (p[0] - seg[0][0]) / (seg[1][0] - seg[0][0]),
         y = seg[0][1] + t * (seg[1][1] - seg[0][1]))
        [p[0], y, p[1] + height / 2, rear_seg_angle(si), si, t * seg_len];

module m3_insert_holes() {
    for (i = [0:num_bolts - 1])
        let (f = box_rim_bolt_frame(i))
            translate([f[0], f[1], f[2]])
                rotate([0, 0, f[3]])
                    rotate([-90, 0, 0])
                        entry_bore(m3_ins_od, boss_chamfer, 1,
                                   m3_ins_depth - boss_chamfer + 0.01);
}

// ---------- Trim-mounting bosses + their pilot holes ----------
// Four bosses per hole on the bolt circle; each facet is perpendicular
// to its hole axis, so every boss base sits flush -- no wedge gaps.
z_facet = wall_width;

module mounting_bosses() {
    per_hole_frame()
        for (ang = boss_angles)
            translate(concat(boss_xy(ang), [z_facet - 0.4]))
                cylinder(h = boss_h + 0.4, d = boss_od);  // 0.4 embed: manifold weld
}

module boss_screw_holes() {
    top = z_facet + boss_h;   // boss face
    per_hole_frame()
        for (ang = boss_angles)
            translate(concat(boss_xy(ang), [0])) {
                // blind pilot hole
                translate([0, 0, top - boss_hole_depth])
                    cylinder(h = boss_hole_depth + 0.01, d = boss_hole_d);
                // 45-deg entry chamfer
                translate([0, 0, top - boss_chamfer])
                    cylinder(h = boss_chamfer + 0.01, d1 = boss_hole_d,
                             d2 = boss_hole_d + 2 * boss_chamfer);
                // clear any z-fighting above the boss face
                translate([0, 0, top])
                    cylinder(h = 1, d = boss_hole_d + 2 * boss_chamfer);
            }
}

// ---------- Accessors for box-split-*.scad / backpanel.scad (use <>
// exports functions, not variables) ----------
function box_Xe() = Xe;
function box_num_rear_segments() = len(rear_segments);
function box_rear_segment(i) = rear_segments[i];   // [[x0,y0],[x1,y1]], left to right
function box_rear_angle(i) = rear_seg_angle(i);    // deg, same convention as segment_frame()
function box_hole_x(i) = hole_x(i);
function box_face_y(x) = Yc - sqrt(R * R - x * x);
function box_gap_cut_x(h) =
    let (xm = R * sin((hole_t(h - 1) + hole_t(h)) / 2))
    len([for (d = divider_after_hole) if (d == h) d]) > 0
        ? xm + divider_thickness / 2 : xm;
// x at the center of an outer chamber wall's full (doubled) width -- see
// dividers()' outer_left/outer_right. is_left selects divider_after_hole's
// first entry (left outer wall) vs. its last (right outer wall).
function box_outer_wall_mid_x(is_left) =
    let (h = is_left ? divider_after_hole[0] : divider_after_hole[len(divider_after_hole) - 1],
         mid = R * sin((hole_t(h - 1) + hole_t(h)) / 2))
    is_left ? mid - divider_thickness / 2 : mid + divider_thickness / 2;

// ---------- Assemble ----------
module arched_hole_bar() {
    // concave arc face up, flat bottom on Z=0, width along Y
    translate([0, height / 2, 0])
        rotate([90, 0, 0])
            difference() {
                union() {
                    difference() {
                        linear_extrude(height, convexity = 10)
                            profile_2d();
                        shell_cavity(rear_cut = true);
                        per_hole_frame() stepped_cutter();
                    }
                    dividers();
                    back_lip();
                    mounting_bosses();
                }
                boss_screw_holes();
                m3_insert_holes();
            }
}

arched_hole_bar();
