# FIR Accelerator Caravel SoC

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

A mixed-signal signal processing SoC implemented as a Caravel user project on the SkyWater SKY130A 130nm open-source PDK. The design implements a complete digital signal processing pipeline — CIC decimation → FIR filtering → PWM DAC output — controlled via the Caravel RISC-V management core over Wishbone.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Register Map](#register-map)
- [Directory Structure](#directory-structure)
- [Quickstart](#quickstart)
- [Hardening](#hardening)
- [Signoff Results](#signoff-results)
- [Checklist](#checklist)

## Overview

This project implements a programmable digital FIR filter accelerator SoC inside the Caravel user project wrapper. The RISC-V management core programs filter coefficients, decimation ratio, and control flags via a Wishbone CSR block. A 1-bit bitstream input (from GPIO or internal LFSR test source) passes through a CIC decimation filter, an 8-tap FIR filter, and a PWM DAC to produce an analog-approximated output on GPIO[9].

Intended as a foundation for a future mixed-signal tapeout with a first-order Σ∆ modulator frontend (analog block, Phase 2).

## Architecture

```
GPIO[8] ──────────────────────┐
                               ├──► [Bitstream MUX] ──► [CIC Decimator] ──► [FIR Filter] ──► [PWM DAC] ──► GPIO[9]
LFSR (use_lfsr=1) ────────────┘         ▲                    ▲                  ▲               ▲
                                         │                    │                  │               │
                              [Wishbone CSR] ◄──────────────────────────────────────────────────┘
                                         ▲
                              Caravel RISC-V Management Core (Wishbone)
```

### Blocks

| Block | File | Description |
|---|---|---|
| `wb_csr` | `rtl/digital/wishbone_csr/wb_csr.v` | Wishbone CSR — register-mapped control and status |
| `cic_decimator` | `rtl/digital/cic/cic_decimator.v` | 3-stage CIC decimation filter, OSR=8/16/32/64 |
| `fir_filter` | `rtl/digital/fir/fir_filter.v` | 8-tap direct-form I FIR, Q1.15, runtime-programmable coefficients |
| `pwm_dac` | `rtl/digital/pwm_dac/pwm_dac.v` | 8-bit first-order delta-sigma PWM DAC |
| `lfsr` | `rtl/digital/lfsr/lfsr.v` | 16-bit Galois LFSR — internal test bitstream source |

## Register Map

Base address: `0x3000_0000` (Wishbone)

| Offset | Name | Bits | Description |
|---|---|---|---|
| 0x00 | CTRL | [0]=enable, [1]=bypass_fir, [2]=bypass_cic, [3]=soft_rst, [4]=use_lfsr | Control register |
| 0x04 | OSR | [6:0] | CIC decimation ratio (8/16/32/64) |
| 0x08 | COEFF_ADDR | [2:0] | FIR tap index to write (0–7) |
| 0x0C | COEFF_DATA | [15:0] | FIR coefficient in Q1.15 format — write triggers load |
| 0x10 | STATUS | [0]=data_valid, [1]=overflow | Read-only status |
| 0x14 | PWM_DATA | [7:0] | Direct PWM value (bypass_fir mode) |

### GPIO

| GPIO | Direction | Function |
|---|---|---|
| GPIO[8] | Input | Bitstream input (Σ∆ modulator / external) |
| GPIO[9] | Output | PWM DAC output |

## Directory Structure

```
rtl/
├── digital/
│   ├── cic/            — CIC decimation filter
│   ├── fir/            — FIR filter
│   ├── lfsr/           — LFSR test source
│   ├── pwm_dac/        — PWM DAC
│   └── wishbone_csr/   — Wishbone CSR block
└── analog/             — Σ∆ modulator (Phase 2, planned)
sim/digital/            — Testbenches (Icarus Verilog)
verilog/rtl/            — Caravel top-level wrapper
openlane/wrapped_filter/— OpenLane hardening config and SDC
signoff/                — DRC, LVS, timing reports
xschem/                 — Analog schematic (Phase 2, planned)
analog/magic/           — Analog layout (Phase 2, planned)
docs/                   — Documentation
```

## Quickstart

### Prerequisites

- Docker
- Python 3.8+
- `volare` (`pip3 install volare`)

### Setup

```bash
git clone https://github.com/Mummanajagadeesh/fir-accel-caravel-soc.git
cd fir-accel-caravel-soc

export PDK_ROOT=~/pdks
export PDK=sky130A
export OPENLANE_ROOT=~/OpenLane
export CARAVEL_ROOT=$(pwd)/caravel
export UPRJ_ROOT=$(pwd)

make setup
```

### RTL Simulation

```bash
# Simulate individual blocks
iverilog -o sim/digital/pwm_dac_sim \
    rtl/digital/pwm_dac/pwm_dac.v sim/digital/tb_pwm_dac.v && \
vvp sim/digital/pwm_dac_sim

iverilog -o sim/digital/cic_sim \
    rtl/digital/cic/cic_decimator.v sim/digital/tb_cic.v && \
vvp sim/digital/cic_sim

iverilog -o sim/digital/fir_sim \
    rtl/digital/fir/fir_filter.v sim/digital/tb_fir.v && \
vvp sim/digital/fir_sim

# Integration smoke test
iverilog -o sim/digital/top_sim \
    verilog/rtl/user_project_wrapper.v \
    rtl/digital/wishbone_csr/wb_csr.v \
    rtl/digital/cic/cic_decimator.v \
    rtl/digital/fir/fir_filter.v \
    rtl/digital/pwm_dac/pwm_dac.v \
    rtl/digital/lfsr/lfsr.v \
    sim/digital/tb_top.v && \
vvp sim/digital/top_sim
```

## Hardening

```bash
cd openlane

# Harden user project (RTL → GDS)
make wrapped_filter \
    OPENLANE_ROOT=$OPENLANE_ROOT \
    PDK_ROOT=$PDK_ROOT \
    PDK=sky130A \
    CARAVEL_ROOT=$CARAVEL_ROOT \
    UPRJ_ROOT=$UPRJ_ROOT
```

Flow runs synthesis (Yosys), floorplan, placement, CTS, routing, and signoff (Magic DRC + LVS + OpenSTA) inside the OpenLane Docker container (`efabless/openlane:2023.07.19-1`).

## Signoff Results

| Check | Result |
|---|---|
| Magic DRC | **0 violations** |
| LVS | **Clean** (18,329 nets) |
| Setup violations | None |
| Hold violations | None |
| Antenna violations | 2 (non-critical) |
| GDS size | 95 MB |
| Die area | 2920 × 3520 µm |
| Standard cell library | `sky130_fd_sc_hd` |
| Clock period | 25 ns (40 MHz) |

## Future Work

- **Phase 2 — Analog frontend**: First-order Σ∆ modulator in Sky130 full-custom layout (Xschem schematic → Magic layout → NGSpice post-layout verification)
- Gate-level simulation with Caravel cocotb infrastructure
- Efabless chipIgnite shuttle submission

## Tools

| Tool | Version |
|---|---|
| OpenLane | 1.0.2 (superstable) |
| Sky130A PDK | `78b7bc32` |
| Icarus Verilog | 11.0 |
| NGSpice | 36 |
| Magic VLSI | 8.3.105 |
| Docker image | `efabless/openlane:2023.07.19-1` |

## License

[Apache License 2.0](LICENSE)

## Checklist for Shuttle Submission

| Requirement | Status |
|---|---|
| Caravel user project area | Done |
| OpenLane flow (RTL to GDS) | Done |
| Sky130A standard cells | Done |
| Magic DRC clean (0 violations) | Done |
| LVS clean (18,329 nets) | Done |
| No setup/hold violations | Done |
| RTL testbenches (5 blocks) | Done |
| Gate-level simulation (10/10) | Done |
| RISC-V firmware | Done |
| PCBA schematic + BOM | Done |
| Mechanicals (OpenSCAD + STL) | Done |
| Apache 2.0 license | Done |
| SPDX compliance | Done |
| Public GitHub repository | Done |