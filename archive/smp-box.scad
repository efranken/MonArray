// ============================================================
// Arched speaker bar: concave-arc profile, shelled hollow with an open
// back + seating lip, BMR cutouts, trim bosses, dividers, M3 rim inserts.
// ============================================================

include <smp-common.scad>

// ---------- Profile: rectangle whose top is the concave arc ----------
module profile_2d() {
    n = 64;
    polygon(concat(
        [for (i = [0:n]) let (t = -half_deg + 2 * half_deg * i / n)
            [R * sin(t), Yc - R * cos(t)]],
        [[Xe, 0], [-Xe, 0]]));
}

// ---------- Bottom/end-face chamfer ----------
// (x,z) cross-section of the box's end -- the (x,z)-plane analogue of
// profile_2d(), constant across y near the flat rear where profile_2d()
// spans the full x range. Chamfers the edge where the flat bottom cap
// (z=0) meets each end face (x=+-Xe); profile_2d() itself can't express
// this since it's the same shape at every z.
module end_profile_2d() {
    polygon([[Xe, height], [Xe, box_chamfer_leg], [Xe - chamfer_dx, 0],
             [-(Xe - chamfer_dx), 0], [-Xe, box_chamfer_leg], [-Xe, height]]);
}

module end_rect_2d() {
    translate([-Xe, 0]) square([2 * Xe, height]);
}

// genuine offset() of end_profile_2d(), same technique as cavity_2d()'s
// outer_cap_open_2d() -- so everything derived from this (the cut below,
// the relief shell_cavity() needs, back_lip()) reacts automatically if
// end_profile_2d()'s corner treatment ever changes, instead of a second
// hand-derived miter-point calculation to keep in sync by hand.
module end_cavity_2d() {
    offset(delta = -wall_width, chamfer = false) end_profile_2d();
}

eps_chamfer = 0.1;  // coincident-face overhang for the sweeps below, see CLAUDE.md
y_sweep_hi  = Yc - R + arc_depth + 10;  // just past the part's actual depth at the ends

// sweeps a 2D (x,z) shape along y, from y0 to y1; children()'s (x,y)
// stand in for (x,z), so a plain linear_extrude does the sweep.
module sweep_y(y0, y1) {
    translate([0, y1, 0])
        rotate([90, 0, 0])
            linear_extrude(y1 - y0)
                children();
}

// what the chamfer removes from a plain rectangular end, grown by eps:
// two of that region's edges land exactly on the box's own bottom (z=0)
// and end (x=Xe) faces, and a coincident-face cut is a CGAL-fine/
// OpenCSG-preview-glitchy gotcha (see CLAUDE.md).
module end_bottom_chamfer_cut() {
    sweep_y(-10, y_sweep_hi)
        offset(delta = eps_chamfer, chamfer = false)
            difference() {
                end_rect_2d();
                end_profile_2d();
            }
}

// what a naive Xi-rectangle cavity assumption over-removes near the two
// bottom corners, relative to the true end_cavity_2d() -- subtracted
// from shell_cavity() so the wall stays wall_width thick through the
// chamfer instead of the cavity breaching it.
module end_bottom_chamfer_relief() {
    sweep_y(-10, y_sweep_hi)
        offset(delta = eps_chamfer, chamfer = false)
            difference() {
                offset(delta = -wall_width, chamfer = false) end_rect_2d();
                end_cavity_2d();
            }
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
// automatically if that shape changes. They meet at cap_y, a margin
// below the lowest facet point; the assert below catches a future
// rear-end feature growing taller than cap_y.
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

// offset() would also inset the rear edge (y=0), which must stay flush.
// Fix: mirror outer_cap_2d() across y=0 and union first, so that edge
// becomes interior (coincident, merged) instead of a boundary to offset.
module outer_cap_open_2d() {
    intersection() {
        offset(delta = -wall_width, chamfer = false)
            union() {
                outer_cap_2d();
                mirror([0, 1, 0]) outer_cap_2d();
            }
        translate([-Xe - 10, 0, 0])
            square([2 * (Xe + 10), cap_y + wall_width + 15]);   // keep only the y >= 0 half
    }
}

module cavity_2d() {
    union() {
        outer_cap_open_2d();
        facet_cap_2d();
    }
}

// rear_cut = false: flush at y = 0, for clipping additive features so
// they never protrude past the rear plane. rear_cut = true: extended
// 1mm past the rear face, for the actual shell subtraction (cutting
// flush against a coincident face risks a degenerate boundary).
module shell_cavity(rear_cut = false) {
    difference() {
        union() {
            translate([0, 0, wall_width])
                linear_extrude(height - 2 * wall_width, convexity = 10)
                    cavity_2d();
            if (rear_cut)
                translate([-Xi, -1, wall_width])
                    cube([2 * Xi, 1, height - 2 * wall_width]);
        }
        end_bottom_chamfer_relief();
    }
}

// ---------- Dividers between selected hole pairs ----------
// Slabs at the chord midpoints, clipped to the cavity in ONE
// intersection so the expensive faceted extrude is evaluated once.
module dividers() {
    intersection() {
        union() {
            for (h = divider_after_hole)
                translate([R * sin((hole_t(h - 1) + hole_t(h)) / 2)
                           - divider_thickness / 2, -1, -1])
                    cube([divider_thickness, bar_depth + arc_depth + 2, height + 2]);
        }
        shell_cavity();
    }
}

// ---------- Seating lip around the open back ----------
// Picture-frame rim for the backpanel to seat against, derived directly
// from end_cavity_2d() -- the actual cavity boundary, not a hand-
// maintained Xi rectangle -- so it automatically follows whatever
// end_profile_2d()'s corner treatment currently is. Outer edge grown by
// eps (coincident-face union, see CLAUDE.md); inner cutout overhangs
// past the open back on both sides for a clean subtraction.
module back_lip() {
    difference() {
        sweep_y(0, back_lip_depth)
            offset(delta = eps_chamfer, chamfer = false)
                end_cavity_2d();
        sweep_y(-1, back_lip_depth + 1)
            offset(delta = -back_lip_width, chamfer = false)
                end_cavity_2d();
    }
}

// ---------- M3 heat-set insert holes around the rear rim ----------
module m3_insert_holes() {
    for (p = rim_bolt_pts())
        translate([p[0], 0, p[1] + height / 2])
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

// ---------- Accessors for box_print.scad (use <> exports functions,
// not variables) ----------
function box_Xe() = Xe;
function box_hole_x(i) = hole_x(i);
function box_face_y(x) = Yc - sqrt(R * R - x * x);
function box_gap_cut_x(h) =
    let (xm = R * sin((hole_t(h - 1) + hole_t(h)) / 2))
    len([for (d = divider_after_hole) if (d == h) d]) > 0
        ? xm + divider_thickness / 2 : xm;

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
                        end_bottom_chamfer_cut();
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
