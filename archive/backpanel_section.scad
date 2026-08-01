// ============================================================
// Inspection view: backpanel.scad sliced through half its thickness
// (z = panel_thick/2), which is exactly where the wire channels sit --
// so this cut opens them up as visible grooves from a top-down view,
// along with the hub bore and the breakthrough holes at each channel's
// far end. Not a printable part; just for checking the channel layout.
// ============================================================

include <params.scad>
use <backpanel.scad>

intersection() {
    back_panel();
    translate([-10000, -10000, -1])
        cube([20000, 20000, panel_thick / 2 + 1]);
}
