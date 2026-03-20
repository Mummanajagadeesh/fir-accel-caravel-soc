// SPDX-FileCopyrightText: 2026 Mummana Jagadeesh
// SPDX-License-Identifier: Apache-2.0
//
// FIR Accelerator Breakout Board Enclosure
// PCB dimensions: 60mm x 40mm
// Designed for FDM 3D printing (PLA/PETG)

// Parameters
pcb_x = 60;
pcb_y = 40;
pcb_z = 1.6;
wall  = 2.0;
floor = 2.0;
lid_h = 3.0;
inner_h = 15.0;  // tall enough for connectors/headers
post_r = 2.0;
post_h = 3.0;
screw_r = 1.1;   // M2.2 self-tap

// Mounting hole positions (3mm from corners)
mh_offset = 3.5;
mh_pos = [
    [mh_offset,       mh_offset      ],
    [pcb_x-mh_offset, mh_offset      ],
    [mh_offset,       pcb_y-mh_offset],
    [pcb_x-mh_offset, pcb_y-mh_offset]
];

module mounting_post(h) {
    difference() {
        cylinder(r=post_r, h=h, $fn=20);
        cylinder(r=screw_r, h=h+1, $fn=16);
    }
}

module base() {
    difference() {
        // Outer shell
        cube([pcb_x + 2*wall, pcb_y + 2*wall, floor + inner_h]);
        // Inner cavity
        translate([wall, wall, floor])
            cube([pcb_x, pcb_y, inner_h + 1]);
        // GPIO[8] input slot - left side
        translate([0, pcb_y*0.4 + wall - 3, floor + 2])
            cube([wall + 1, 6, 8]);
        // GPIO[9] output slot - right side
        translate([pcb_x + wall - 0.5, pcb_y*0.6 + wall - 3, floor + 2])
            cube([wall + 1, 6, 8]);
        // UART header cutout - front
        translate([pcb_x*0.4 + wall - 5, 0, floor + 4])
            cube([10, wall + 1, 8]);
        // Power connector cutout - back
        translate([pcb_x*0.4 + wall - 4, pcb_y + wall - 0.5, floor + 4])
            cube([8, wall + 1, 8]);
    }
    // Mounting posts
    for (p = mh_pos) {
        translate([p[0] + wall, p[1] + wall, floor])
            mounting_post(post_h);
    }
}

module lid() {
    difference() {
        cube([pcb_x + 2*wall, pcb_y + 2*wall, lid_h]);
        // Label recess
        translate([wall + 5, wall + 5, lid_h - 0.8])
            linear_extrude(1)
                text("FIR SoC", size=5, font="Liberation Sans:style=Bold");
        // Ventilation slots
        for (i = [0:3]) {
            translate([wall + 8 + i*12, wall + pcb_y/2 - 5, -0.1])
                cube([6, 10, lid_h + 0.2]);
        }
    }
}

// Render base by default
// Use: openscad -D 'part="lid"' to render lid
part = "base"; // override with -D 'part="lid"'

if (part == "base") {
    base();
} else if (part == "lid") {
    lid();
} else {
    // Show both for preview
    base();
    translate([0, pcb_y + 2*wall + 5, 0])
        lid();
}
