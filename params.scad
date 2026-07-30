// ============================================================
// All parameters for box.scad and trim.scad, grouped below so
// nothing needs to be duplicated or hand-synced between the two
// files. Both files `include <params.scad>`.
// ============================================================

/* [Shared: bore / mounting-boss geometry] */
bmr_od       = 54.5;   // cutout circle diameter, mm
boss_hole_d  = 2.9;    // screw pilot hole diameter, mm
boss_wall    = 4;      // material around the screw hole, mm
boss_od      = boss_hole_d + 1.5 * boss_wall;  // boss outer diameter, mm
boss_h       = 4;      // boss height above the facet, mm
boss_bc_d    = bmr_od + 10;  // bolt circle diameter (centers), mm
boss_chamfer = 1;      // 45-deg chamfer depth at hole entry, mm
boss_angles  = [45, 135, 225, 315];  // clocked from vertical -> square pattern
$fn          = 30;

/* [Box-only parameters] */
arc_length   = 805.45;  // length along the arc face, mm
arc_depth    = 54.78;   // sagitta / rise of the arc, mm
baffle_space = 1;       // thickness of trim over bmrs
bmr_id       = 44.8;    // cutout circle inner diameter, mm
end_space    = 10;      // clearance: box end -> nearest hole edge (along arc), mm
height       = 70;      // extrusion height, mm
wall_width   = 4;       // shell wall thickness, mm
bar_depth    = 63;      // box depth at mid-span (thinnest point), mm
num_holes    = 10;      // holes are spaced equidistantly to fill the span
divider_after_hole = [4, 5, 6];  // 1-indexed: wall placed between this hole and the next
divider_thickness  = wall_width; // thickness of each dividing wall, mm
boss_hole_depth    = boss_h + 2; // blind: stops 2 mm short of the outer face
back_lip_depth     = 5;          // how far the lip reaches into the cavity from the open back, mm
back_lip_width     = 4;          // width of the lip shelf, mm
m3_ins_od          = 4.2;        // M3 heat-set insert diameter, mm
m3_ins_depth       = 4;          // insert hole depth from the exposed rear face, mm
num_bolts          = 12;         // insert holes, equally spaced around the rear rim

/* [Trim-only parameters] */
trim_id          = 50;                  // center bore diameter, mm
trim_step_od     = bmr_od - 0.5;        // plug OD: 0.5 mm total clearance in the bore
trim_mount_depth = 3;                   // depth of boss-capture socket at the plug tip, mm
trim_step_depth  = boss_h + 2;          // plug length: boss height + 2 mm
trim_od          = boss_bc_d + boss_od; // circle tangent to the outer edges of the 4 bosses
boss_hole        = boss_hole_d;         // == boss_id: screw clearance hole diameter
flange_depth     = 2;                   // flange (cap) thickness, mm
total_depth      = flange_depth + trim_step_depth;  // overall trim height, mm

/* [Backpanel-only parameters] */
panel_thick   = 5;    // backpanel thickness, mm
bp_hole_od    = 6;    // counterbore diameter, mm
bp_hole_depth = 3;    // counterbore depth, mm
bp_hole_id    = 3.1;  // clearance-bore diameter through the rest of the panel, mm

// wire channels: 8 straight horizontal bores (one cable pair per box
// chamber), tightly stacked in one column at mid-height, all running
// through to a single thru-hole (the hub) for pulling wires out
channel_d          = 2;      // wire channel diameter, mm
channel_gap        = 0.5;    // minimum gap between stacked channels, mm
hub_margin         = 2;      // clearance added around the channel stack to size the hub bore, mm
hub_x_frac         = 1 / 3;  // hub position along the panel length, fraction from the left edge
channel_edge_frac  = 7 / 8;  // outer channel pair position, fraction of the half-length (from center toward each edge)
channel_mid_offset = 10;     // inner channel pair position, mm from center
