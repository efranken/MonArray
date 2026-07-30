// ============================================================
// Trim piece: stepped cap/plug that mounts over the mounting
// bosses on arched_hole_bar_boss.scad, plugging into the
// bmr_od bore from the outside.
//
// Assembly (outside -> in):
//   - Flange  (thin, wide disc) rests on the bar's exterior arc
//     face, OD = trim_od (circumscribes the 4 bosses), 2 mm tall.
//   - Step/plug (narrow tube) drops down inside the bmr_od bore,
//     OD = trim_step_od (bmr_od - 0.5 mm clearance), height =
//     trim_step_depth (boss height + 2 mm).
//   - A constant bore of trim_id runs through both, matching the
//     original model's mounting-boss layout so screws can pass
//     through the trim into each boss's pilot hole.
//
// All parameters (trim geometry, plus the bmr_od/boss_* values shared
// with box.scad) come from params.scad, so the two files can't drift
// out of sync.
// ============================================================

include <params.scad>

echo(str("trim_od = ", trim_od, " mm | trim_step_od = ", trim_step_od,
         " mm | total_depth = ", total_depth, " mm"));

// ---------- Stepped body ----------
// Every cross-section here is a plain circle/annulus (no arc facets
// like the source bar has), so this is just two stacked cylinders
// with a constant-diameter bore -- no need for rotate_extrude.
// z = 0 is the flange's outer (exterior-facing) face; z increases
// going inward, ending at the plug tip (z = total_depth).
module trim_body() {
    difference() {
        union() {
            cylinder(h = flange_depth, d = trim_od);
            translate([0, 0, flange_depth])
                cylinder(h = trim_step_depth, d = trim_step_od);
        }
        translate([0, 0, -0.5])
            cylinder(h = total_depth + 1, d = trim_id);
    }
}

// ---------- Per-boss hole feature ----------
// From the flange's outer face inward: chamfer, then a clearance
// through-hole, then a socket at the tip sized to boss_od
// (trim_mount_depth deep) that registers the trim onto each boss.
// Each section is a plain cylinder (using d1/d2 for the taper);
// stacking distinct-radius cylinders in a union is a standard, safe
// OpenSCAD idiom -- no rotate_extrude/polygon needed.
module boss_hole_cutter() {
    socket_z = total_depth - trim_mount_depth;  // where the boss socket begins
    r_chamfer_d = boss_hole + 2 * boss_chamfer; // widened diameter at the entry face
    union() {
        // entry overhang, for a clean cut through the flange's outer face
        translate([0, 0, -0.6])
            cylinder(h = 0.6, d = r_chamfer_d);
        // countersink taper down to the clearance shaft diameter
        cylinder(h = boss_chamfer, d1 = r_chamfer_d, d2 = boss_hole);
        // clearance shaft
        translate([0, 0, boss_chamfer])
            cylinder(h = socket_z - boss_chamfer, d = boss_hole);
        // boss-capture socket at the tip, with overhang past the tip
        translate([0, 0, socket_z])
            cylinder(h = trim_mount_depth + 0.6, d = boss_od);
    }
}

module trim_boss_holes() {
    for (ang = boss_angles)
        translate([boss_bc_d / 2 * sin(ang), boss_bc_d / 2 * cos(ang), 0])
            boss_hole_cutter();
}

// ---------- Assemble ----------
module trim() {
    // flange face down, plug pointing up, matching the flange-first
    // (z=0 = outer face) convention used above
    difference() {
        trim_body();
        trim_boss_holes();
    }
}

trim();
