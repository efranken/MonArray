// ============================================================
// Shared parameters for all .scad files.
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
bmr_id       = 43.8;    // cutout circle inner diameter, mm
end_space    = 30;      // clearance: box end -> nearest hole edge (along arc), mm
height       = 70;      // extrusion height, mm
wall_width   = 4;       // shell wall thickness, mm
bar_depth    = 63;      // box depth at mid-span (thinnest point), mm
rear_end_depth = 117.8; // box depth (front-to-back) at the left/right ends, mm -- see profile_2d()
                        // 117.78 makes the entire rear one flat plane (no "\_/" bend at all)
                        // -- recompute if arc_length/arc_depth/bar_depth change

// box-split-*.scad joint key/valley: locates the 3 printed segments during
// glue-up. Ribs run the box's full width (Y), parallel to the top/bottom
// edges, at joint_z0 above the box's own bottom edge (Z=0). Valley is
// deeper/taller than the key so they don't bind on insertion.
joint_z0              = 10;   // rib's Z position above the box's bottom edge, mm
joint_key_protrusion  = 2;    // key: how far it pokes out from the cut face, mm
joint_valley_depth    = 2.5;  // valley: how far it's recessed into the cut face, mm
joint_key_height      = 4;    // key: Z extent, mm
joint_valley_height   = 4.5;  // valley: Z extent, mm

num_holes          = 10;        // holes are spaced equidistantly to fill the span
divider_after_hole = [4, 5, 6];  // 1-indexed: wall placed between this hole and the next
divider_thickness  = wall_width; // thickness of each dividing wall, mm
boss_hole_depth    = boss_h + 2; // blind: stops 2 mm short of the outer face
back_lip_depth     = 5;          // how far the lip reaches into the cavity from the open back, mm
back_lip_width     = 5;          // width of the lip shelf, mm
m3_ins_od          = 4.2;        // M3 heat-set insert diameter, mm
m3_ins_depth       = 4;          // insert hole depth from the exposed rear face, mm
num_bolts          = 12;         // insert holes, equally spaced around the rear rim
bmr_fn             = 96;         // circle resolution for the BMR cutout only (global $fn stays low for everything else)

/* [Trim-only parameters] */
trim_id          = 47;                  // center bore diameter, mm
trim_id_chamfer  = 3;                   // chamfer depth on the center bore's inner edge, mm
trim_step_od     = bmr_od - 0.5;        // plug OD: 0.5 mm total clearance in the bore
trim_step_depth  = boss_h + 2;          // plug length: boss height + 2 mm
boss_hole        = boss_hole_d;         // == boss_id: screw clearance hole diameter
flange_depth     = 3;                   // flange (cap) thickness, mm
total_depth      = flange_depth + trim_step_depth;  // overall trim height, mm

/* [Backpanel-only parameters] */
panel_thick   = 5;    // backpanel thickness, mm
bp_hole_od    = 6;    // counterbore diameter, mm
bp_hole_depth = 3;    // counterbore depth, mm
bp_hole_id    = 3.5;  // clearance-bore diameter through the rest of the panel, mm

// wire channels: 8 push-threadable bores (one Cat5e conductor each, 2
// per chamber), each a single junction-free lumen -- straight bus, then
// one straight funnel dive (equal x/y/z reach -- a true 45 degrees in
// both the in-plane peel direction and through the panel face) out to
// an oversized mouth at the panel's inner face. Left/right chambers
// enter the riser from opposite sides and reuse bus heights, so the
// stack is 6 tall, not 8. A prior two-arc (peel + surfacing) design was
// unpushable: no straight lead-in between them (compound bend, curvature
// plane flips) and thin-wall internal overhangs at the tangent joints
// print rougher than modeled -- see CLAUDE.md.
channel_d               = 1.5;   // wire channel diameter, mm (~0.5mm clearance over a ~1.0mm insulated Cat5e conductor)
channel_gap             = 0.5;   // minimum gap between stacked channels, mm
channel_manifold_margin = 0.5;   // clearance added around the bus stack's height when sizing the riser bore, mm
channel_riser_wall      = 1.5;   // wall thickness around the riser bore, mm
channel_pair_dx         = 5;     // x offset between a chamber's 2 entry holes, mm
channel_funnel_mult     = 2.5;   // funnel mouth diameter, as a multiple of channel_d
channel_face_overshoot  = 1.5;   // funnel mouth extends this far past the inner face, mm (clean subtraction, easier entry)
channel_edge_frac       = 7 / 8; // outer channel pair position, fraction of the half-length (from center toward each edge)
channel_mid_offset      = 10;    // inner channel pair position, mm from center

// keystone jack mount: cutout goes through the panel (panel_thick is the
// mounting wall) so the jack is pluggable from the exterior; the housing
// extends inward to the punch-down terminal. Standard 14.5x16.1mm
// keystone opening (Leviton/Legrand/ICC-style) -- adjust to match a
// specific jack's datasheet if needed.
ks_body_w           = 20;    // body/tang-flare cavity width behind the wall, mm
ks_body_h           = 22;    // body/tang-flare cavity height behind the wall, mm
ks_cutout_clearance = 0.3;   // print clearance added to the cutout so the jack slides through, mm
ks_cutout_w         = 14.8;  // standard keystone cutout width, mm
ks_cutout_h         = 16.3;  // standard keystone cutout height, mm
ks_cutout_y_offset  = 1.25;   // cutout height starts this far above the body cavity's bottom edge, mm
ks_jack_len         = 36;    // overall length, panel's outer face to rear of punch-down block, mm
ks_wall             = 3;     // structural wall thickness around the housing, mm
ks_x_frac           = 1 / 3; // keystone housing (and channel gathering point) position along the panel length, fraction from the left edge
ks_y_offset         = 10;    // housing center y, relative to mid-height (mm; change to reposition)

/* [Sectioning for print (archive/box_print.scad / archive/backpanel_print.scad -- repoint at the smp files to reuse)] */
// ~795mm parts cut into 4 segments for a 300mm-class printer. Box prints
// standing on its cut face (near-zero support); panel prints flat.
// Panel cuts stagger off box cuts so the bolted panel bridges every
// joint. Filament dowels + glue + backpanel bolts align each joint.
printer_bed        = 300;      // max printable dimension, mm (Creality K2 Pro)
box_cut_after_hole = [2, 4, 7]; // cut in the gap after hole N (1-indexed); a divider gap cuts at the divider face
panel_cuts         = [-190, 60, 230]; // backpanel cut x positions, mm; kept clear of box cuts/keystone/bolts/channels
joint_pin_d        = 2.0;      // filament-dowel hole diameter, mm (1.75mm filament + slop)
joint_pin_len      = 12;       // total dowel length across a joint, mm (half in each segment)
joint_funnel_d     = 3;        // wire-channel mouth diameter at a panel seam, mm
joint_funnel_len   = 1.5;      // funnel taper length on each side of a seam, mm
