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
bmr_fn             = 96;         // circle resolution for the BMR cutout only (global $fn stays low for everything else)

/* [Trim-only parameters] */
trim_id          = 50;                  // center bore diameter, mm
trim_id_chamfer  = 2;                   // chamfer depth on the center bore's inner edge, mm
trim_step_od     = bmr_od - 0.5;        // plug OD: 0.5 mm total clearance in the bore
trim_step_depth  = boss_h + 2;          // plug length: boss height + 2 mm
boss_hole        = boss_hole_d;         // == boss_id: screw clearance hole diameter
flange_depth     = 2;                   // flange (cap) thickness, mm
total_depth      = flange_depth + trim_step_depth;  // overall trim height, mm

/* [Backpanel-only parameters] */
panel_thick   = 5;    // backpanel thickness, mm
bp_hole_od    = 6;    // counterbore diameter, mm
bp_hole_depth = 3;    // counterbore depth, mm
bp_hole_id    = 3.1;  // clearance-bore diameter through the rest of the panel, mm

// wire channels: 8 bores (one insulated Cat5e conductor each, 2 per box
// chamber). Threading requirement drives everything here: each channel
// is ONE continuous, junction-free lumen with only gentle sweeps (like
// electrical conduit), so a strand pushed in at the chamber MUST emerge
// at the riser -- no sharp elbows (a pushed tip dead-ends into the
// corner wall), no channel-to-channel junctions (ambiguous exit), no
// coaxial/near-parallel merged bores (lane-jumping; also a CGAL
// degeneracy -- coincident curved surfaces -> minutes-long renders).
// Layout is a cable-loom "bus": parallel horizontal bores at distinct
// stacked heights run from the riser outward; each channel peels off at
// its chamber via a tangent-continuous in-plane arc (channel_bend_r)
// directly into a second arc (channel_exit_r) that surfaces through the
// panel's inner face at ~47 deg, forming the angled entry hole. Chambers
// left of the riser enter it from the opposite side to chambers right of
// it, so the two sides reuse bus heights: the stack is 6 tall, not 8.
channel_d               = 1.5;   // wire channel diameter, mm (~0.5mm clearance over a ~1.0mm insulated Cat5e conductor)
channel_gap             = 0.5;   // minimum gap between stacked channels, mm
channel_manifold_margin = 0.5;   // clearance added around the bus stack's height when sizing the riser bore, mm
channel_riser_wall      = 1.5;   // wall thickness around the riser bore, mm
channel_pair_dx         = 5;     // x offset between a chamber's 2 entry holes, mm
channel_bend_r          = 10;    // radius of the in-plane peel-off arc (horizontal -> vertical), mm
channel_exit_r          = 8;     // radius of the surfacing arc through the inner face, mm
channel_edge_frac       = 7 / 8; // outer channel pair position, fraction of the half-length (from center toward each edge)
channel_mid_offset      = 10;    // inner channel pair position, mm from center

// keystone jack mount: the cutout goes straight through the panel itself
// (panel_thick doubles as the keystone-rated mounting wall) so the jack
// is reachable -- and a patch cable pluggable -- from the panel's outer
// (exterior) face; the housing extends inward from there into the box
// for the rest of the jack's length, ending at the punch-down terminal,
// which stays buried (wired once during assembly, matching how a real
// keystone jack is normally used). Real keystone jacks snap-fit via a
// barbed tang (not friction fit): the tang compresses through the
// cutout on insertion, then a cavity behind the panel lets it flare back
// out and catch its shoulder on the panel's inner face. Dimensions below
// follow the standard keystone interface (cutout size is the widely-used
// 14.5 mm x 16.1 mm keystone opening, consistent across
// Leviton/Legrand/ICC-style jacks); adjust to match a specific jack's
// datasheet if needed. The front retention flange (~22.3 mm x 18.5 mm)
// simply rests against the panel's outer face around the cutout and
// needs no dedicated cut geometry, since the panel is much larger than it.
ks_cutout_w         = 16.1;  // standard keystone cutout width, mm
ks_cutout_h         = 14.5;  // standard keystone cutout height, mm
ks_cutout_clearance = 0.3;   // print clearance added to the cutout so the jack slides through, mm
ks_body_w           = 16.3;  // body/tang-flare cavity width behind the wall, mm
ks_body_h           = 14.8;  // body/tang-flare cavity height behind the wall, mm
ks_jack_len         = 36;    // overall length, panel's outer face to rear of punch-down block, mm
ks_wall             = 4;     // structural wall thickness around the housing, mm
ks_x_frac           = 1 / 3; // keystone housing (and channel gathering point) position along the panel length, fraction from the left edge
ks_y_offset         = 0;     // housing center y, relative to mid-height (mm; change to reposition)

/* [Sectioning for print (box_print.scad / backpanel_print.scad)] */
// The full parts are ~795mm long; both get cut into 4 segments for a
// 300mm-class printer. Box segments print STANDING on their cut face
// (turns every wall vertical -> ~zero support); the panel prints flat,
// outer face down. Panel cuts are staggered ~50mm+ off the box cuts so
// the bolted panel bridges every box joint (and vice versa) and no two
// seams line up into a through leak path. Alignment at each joint:
// short lengths of 1.75mm filament as dowels in printed holes, plus the
// glue-up itself; the backpanel bolts act as the global jig.
printer_bed        = 300;      // max printable dimension, mm (Creality K2 Pro)
box_cut_after_hole = [2, 4, 7]; // box cut positions, as "in the gap after hole N" (1-indexed).
                                // A gap that carries a divider (see divider_after_hole) cuts at the
                                // divider's face instead of the gap midpoint, so that joint gets the
                                // divider as a full mating bulkhead -- gluing it also seals the chamber.
panel_cuts         = [-190, 60, 230]; // backpanel cut x positions, mm. Keep each >= ~50mm from every box
                                // cut, clear of the keystone/riser zone, bolt holes, and all channel
                                // peel windows (the print file asserts the latter three).
joint_pin_d        = 2.0;      // filament-dowel hole diameter, mm (1.75mm filament + slop)
joint_pin_len      = 12;       // total dowel length across a joint, mm (half in each segment)
joint_funnel_d     = 3;        // wire-channel mouth diameter at a panel seam, mm
joint_funnel_len   = 1.5;      // funnel taper length on each side of a seam, mm
