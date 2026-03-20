# SPDX-FileCopyrightText: 2026 Mummana Jagadeesh
# SPDX-License-Identifier: Apache-2.0

# Mechanicals - FIR Accelerator Breakout Enclosure

Simple two-part enclosure for the FIR Accelerator breakout board.
Designed for FDM 3D printing in PLA or PETG.

## Parts

- `enclosure.scad` — OpenSCAD source (parametric)
- `enclosure_base.stl` — Bottom shell with PCB mounting posts
- `enclosure_lid.stl` — Top cover with label and ventilation slots

## PCB Dimensions

- 60mm x 40mm x 1.6mm
- M2.2 self-tapping screws for PCB mounting (3.5mm from corners)

## Cutouts

- Left side: GPIO[8] input connector slot
- Right side: GPIO[9] output connector slot
- Front: UART debug header
- Back: Power connector

## Print Settings

- Layer height: 0.2mm
- Infill: 20%
- Supports: Not required
- Material: PLA or PETG
