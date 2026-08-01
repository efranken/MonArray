// ============================================================
// Trim cap for each BMR bore: a rounded-rect flange resting on the
// bar's arc face (edges tangent to the 4 mounting bosses) with a plug
// that drops into the bmr_od bore, a chamfered trim_id center opening,
// and 4 countersunk screw clearance holes into the bosses.
// Simplified rewrite of trim.scad -- identical output geometry.
// ============================================================

include <smp-common.scad>

// flange outline: hull of 4 circles on the boss positions -- straight
// edges tangent to each boss, corner fillets exactly boss_od/2
module flange_outline() {
    hull()
        for (ang = boss_angles)
            translate(boss_xy(ang))
                circle(d = boss_od);
}

// z = 0 is the flange's outer face; z increases inward to the plug tip.
module trim_body() {
    difference() {
        union() {
            linear_extrude(flange_depth) flange_outline();
            translate([0, 0, flange_depth])
                cylinder(h = trim_step_depth, d = trim_step_od);
        }
        union() {
            // full-length center bore, overhung past both ends
            translate([0, 0, -0.5])
                cylinder(h = total_depth + 1, d = trim_id);
            // entry chamfer (+0.1 on d1 avoids exact tangency with the plug OD)
            cylinder(h = trim_id_chamfer,
                     d1 = trim_id + 2 * trim_id_chamfer + 0.1, d2 = trim_id);
        }
    }
}

module trim() {
    difference() {
        trim_body();
        // countersunk clearance hole straight through to the plug tip
        for (ang = boss_angles)
            translate(concat(boss_xy(ang), [0]))
                entry_bore(boss_hole, boss_chamfer, 0.6,
                           total_depth - boss_chamfer + 0.6);
    }
}

trim();
