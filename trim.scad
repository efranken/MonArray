// ============================================================
// Trim piece: stepped cap/plug that mounts over the mounting
// bosses on arched_hole_bar_boss.scad, plugging into the
// bmr_od bore from the outside.
//
// Assembly (outside -> in):
//   - Flange (thin plate) rests on the bar's exterior arc face, a
//     rounded rectangle whose straight edges are tangent to the 4
//     bosses' outer edges and whose corner fillet radius equals the
//     boss outer radius (boss_od / 2), 2 mm tall.
//   - Step/plug (narrow tube) drops down inside the bmr_od bore,
//     OD = trim_step_od (bmr_od - 0.5 mm clearance), height =
//     trim_step_depth (boss height + 2 mm).
//   - A constant bore of trim_id runs through both, chamfered
//     trim_id_chamfer mm deep on its outer-face edge (the flange face
//     that also carries the 4 boss holes), matching the original
//     model's mounting-boss layout so screws can pass through the
//     trim into each boss's pilot hole.
//
// All parameters (trim geometry, plus the bmr_od/boss_* values shared
// with box.scad) come from params.scad, so the two files can't drift
// out of sync.
// ============================================================

include <params.scad>

echo(str("trim_step_od = ", trim_step_od, " mm | total_depth = ", total_depth, " mm"));

// ---------- Flange outline ----------
// Rounded rectangle: hull of 4 circles (radius = boss_od / 2) centered
// on the boss positions. This lands the straight edges tangent to each
// boss's outer edge and gives corner fillets matching the boss outer
// radius exactly -- no separate rounding parameter needed.
module flange_outline() {
    hull()
        for (ang = boss_angles)
            translate([boss_bc_d / 2 * sin(ang), boss_bc_d / 2 * cos(ang)])
                circle(d = boss_od);
}

// ---------- Stepped body ----------
// The plug is a plain cylinder (no arc facets like the source bar
// has); the flange is the rounded-rect outline above, extruded.
// z = 0 is the flange's outer (exterior-facing) face; z increases
// going inward, ending at the plug tip (z = total_depth).
module trim_body() {
    difference() {
        union() {
            linear_extrude(flange_depth) flange_outline();
            translate([0, 0, flange_depth])
                cylinder(h = trim_step_depth, d = trim_step_od);
        }
        union() {
            // full-length clearance bore, with overhang past both ends
            translate([0, 0, -0.5])
                cylinder(h = total_depth + 1, d = trim_id);
            // chamfer on the bore's inner edge at the outer (hole-side) face;
            // +0.1 on d1 avoids exact tangency with trim_step_od at z = flange_depth
            cylinder(h = trim_id_chamfer, d1 = trim_id + 2 * trim_id_chamfer + 0.1, d2 = trim_id);
        }
    }
}

// ---------- Per-boss hole feature ----------
// From the flange's outer face inward: chamfer, then a single
// constant-diameter clearance through-hole all the way to the plug
// tip -- no capture socket, no diameter step.
// Each section is a plain cylinder (using d1/d2 for the taper);
// stacking distinct-radius cylinders in a union is a standard, safe
// OpenSCAD idiom -- no rotate_extrude/polygon needed.
module boss_hole_cutter() {
    r_chamfer_d = boss_hole + 2 * boss_chamfer; // widened diameter at the entry face
    union() {
        // entry overhang, for a clean cut through the flange's outer face
        translate([0, 0, -0.6])
            cylinder(h = 0.6, d = r_chamfer_d);
        // countersink taper down to the clearance shaft diameter
        cylinder(h = boss_chamfer, d1 = r_chamfer_d, d2 = boss_hole);
        // clearance shaft, straight through to the tip, with overhang past the tip
        translate([0, 0, boss_chamfer])
            cylinder(h = total_depth - boss_chamfer + 0.6, d = boss_hole);
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
