# FIR Accelerator Caravel User Project

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0) [![User CI](https://github.com/Mummanajagadeesh/fir-accel-caravel-soc/actions/workflows/user_project_ci.yml/badge.svg)](https://github.com/Mummanajagadeesh/fir-accel-caravel-soc/actions/workflows/user_project_ci.yml) [![Caravel Build](https://github.com/Mummanajagadeesh/fir-accel-caravel-soc/actions/workflows/caravel_build.yml/badge.svg)](https://github.com/Mummanajagadeesh/fir-accel-caravel-soc/actions/workflows/caravel_build.yml)

## Table of Contents

- [Overview](#overview)
- [Target Application](#target-application)
- [Architecture](#architecture)
- [Quickstart](#quickstart)
- [Caravel Integration](#caravel-integration)
  - [Verilog Integration](#verilog-integration)
  - [GPIO Configuration](#gpio-configuration)
  - [Layout Integration](#layout-integration)
- [Running Full Chip Simulation](#running-full-chip-simulation)
- [User Project Wrapper Requirements](#user-project-wrapper-requirements)
- [Hardening the User Project using OpenLane](#hardening-the-user-project-using-openlane)
- [Running Timing Analysis](#running-timing-analysis)
- [Verification Status](#verification-status)
- [Deployment Path](#deployment-path)
- [Checklist for Open-MPW Submission](#checklist-for-open-mpw-submission)

## Overview

This repository contains a programmable digital FIR filter accelerator implemented as a Caravel user project on the SkyWater SKY130A 130nm open-source PDK. The design implements a complete fixed-point DSP pipeline: CIC decimation filter, 8-tap FIR filter with runtime-programmable coefficients, and PWM DAC output. The entire pipeline is controlled by the Caravel RISC-V management core via Wishbone-mapped registers.

**Key Features:**
- 3-stage CIC decimation filter (OSR: 8/16/32/64)
- 8-tap direct-form I FIR filter with Q1.15 fixed-point arithmetic
- Runtime-programmable filter coefficients via Wishbone CSR
- 8-bit first-order delta-sigma PWM DAC
- Wishbone B4 peripheral interface (base address: 0x30000000)
- Internal LFSR test source for standalone verification

## Target Application

**Primary: Audio Line-In Filter for Embedded Audio Processing**

This chip processes analog audio signals (microphone, line input) through on-chip sigma-delta conversion, digital filtering, and PWM DAC reconstruction for speaker output or headphone amplification. Targeted at low-cost embedded audio systems (smart speakers, intercoms, voice recorders) where programmable filter profiles are required without external DSP chips.

**Signal Path:**
1. Analog audio input (20 Hz to 20 kHz) connects to external first-order sigma-delta modulator (MAX9814 or similar)
2. 1-bit bitstream at 640 kHz enters chip via GPIO[8]
3. CIC decimator reduces sample rate to 40 kHz (OSR=16)
4. 8-tap FIR applies programmable filtering (equalizer, notch filter, voice band isolation)
5. PWM DAC outputs analog-reconstructed audio via GPIO[9] to RC filter + audio amplifier (LM386)

**Alternative Applications:**
- **Vibration sensor filtering:** Process MEMS accelerometer sigma-delta output for structural health monitoring (50 Hz to 10 kHz bandpass)
- **Power line noise rejection:** 50/60 Hz notch filter for sensor signal cleanup in industrial environments
- **Biomedical signal conditioning:** ECG/EMG frontend with programmable bandwidth (0.5 Hz to 150 Hz)

## Architecture

### Block Diagram

```
                         Caravel Management SoC
                         +---------------------+
                         |   RISC-V (PicoRV32) |
                         |        |             |
                         |   Wishbone Bus       |
                         +----------+----------+
                                    |
                    +---------------+--------------+
                    |           wb_csr             |
                    |  (Control & Status Registers)|
                    +---+------+------+--------+---+
                        |      |      |        |
                      OSR   coeffs  ctrl    bypass
                        |      |      |        |
GPIO[8] ------+         |      |      |        |
              +---> [bit_in MUX]      |        |
LFSR ---------+         |             |        |
                        v             |        |
               +----------------+    |        |
               | cic_decimator  |<---+        |
               |  3-stage, OSR  |             |
               +-------+--------+             |
                        |  16-bit, fs_low      |
                        v                      |
               +----------------+              |
               |   fir_filter   |<-------------+
               |  8-tap Q1.15   |<-- coeff_addr/data
               +-------+--------+
                        |  16-bit
                        v
               +----------------+
               |    pwm_dac     |
               |  8-bit 1st ord |
               +-------+--------+
                        |  1-bit PWM
                        v
                     GPIO[9] ---> RC filter ---> Analog output
```

### Blocks

| Block | File | Description |
|---|---|---|
| `wb_csr` | `rtl/digital/wishbone_csr/wb_csr.v` | Wishbone B4 peripheral CSR. Decodes address offsets, drives all control signals, captures status. Single-cycle ACK. |
| `cic_decimator` | `rtl/digital/cic/cic_decimator.v` | 3-stage CIC filter. Integrators run at full clock rate. Comb sections triggered by decimation pulse at clk / OSR. 16-bit internal word width. |
| `fir_filter` | `rtl/digital/fir/fir_filter.v` | 8-tap direct-form I FIR. Combinational MAC with registered output. Q1.15 coefficients. Initialized to identity (passthrough) on reset. Runtime-loadable via CSR. |
| `pwm_dac` | `rtl/digital/pwm_dac/pwm_dac.v` | First-order delta-sigma PWM modulator. 8-bit accumulator, carry-out is the output bit. |
| `lfsr` | `rtl/digital/lfsr/lfsr.v` | 16-bit Galois LFSR, polynomial x^16 + x^14 + x^13 + x^11 + 1. Seed 0xACE1 on reset. Used as a test bitstream source in place of external hardware. |

### Register Map

Base address: `0x30000000` (Caravel Wishbone user space). All registers are 32-bit. Unused bits read 0, ignored on write.

| Offset | Name | Bits | R/W | Reset | Description |
|---|---|---|---|---|---|
| `0x00` | `CTRL` | `[0]` | R/W | 1 | `enable` - gates the entire pipeline |
| | | `[1]` | R/W | 0 | `bypass_fir` - routes CIC output directly to PWM DAC |
| | | `[2]` | R/W | 0 | `bypass_cic` - routes raw bitstream to FIR input |
| | | `[3]` | R/W | 0 | `soft_rst` - synchronous reset for all datapath registers |
| | | `[4]` | R/W | 0 | `use_lfsr` - selects internal LFSR instead of GPIO[8] |
| `0x04` | `OSR` | `[6:0]` | R/W | 16 | CIC decimation ratio. Valid: 8, 16, 32, 64 |
| `0x08` | `COEFF_ADDR` | `[2:0]` | R/W | 0 | FIR tap index (0 to 7) |
| `0x0C` | `COEFF_DATA` | `[15:0]` | R/W | 0 | FIR coefficient in Q1.15. Write pulses coeff_wr to load into tap COEFF_ADDR |
| `0x10` | `STATUS` | `[0]` | R | - | `data_valid` - high for one cycle per FIR output sample |
| `0x14` | `PWM_DATA` | `[7:0]` | R/W | 0x80 | Direct PWM value when bypass_fir = 1 |

**Example: Loading FIR coefficients (8-tap moving average)**

```c
#define CSR_BASE 0x30000000

// Load h[k] = 1/8 = 0x1000 in Q1.15 for all 8 taps
for (int i = 0; i < 8; i++) {
    *(volatile uint32_t*)(CSR_BASE + 0x08) = i;       // COEFF_ADDR
    *(volatile uint32_t*)(CSR_BASE + 0x0C) = 0x1000;  // COEFF_DATA (triggers load)
}
*(volatile uint32_t*)(CSR_BASE + 0x04) = 16;          // OSR = 16
*(volatile uint32_t*)(CSR_BASE + 0x00) = 0x01;        // enable
```

## Prerequisites

- Docker: [Linux](https://docs.docker.com/desktop/install/linux-install/) | [Windows](https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe) | [Mac with Intel Chip](https://desktop.docker.com/mac/main/amd64/Docker.dmg) | [Mac with M1 Chip](https://desktop.docker.com/mac/main/arm64/Docker.dmg)
- Python 3.8+ with PIP

## Quickstart

### Starting Your Project

1. Clone the repository:

   ```bash
   git clone https://github.com/Mummanajagadeesh/fir-accel-caravel-soc.git
   cd fir-accel-caravel-soc
   ```

2. Set up your local environment:

   ```bash
   export PDK_ROOT=~/pdks
   export PDK=sky130A
   export OPENLANE_ROOT=~/OpenLane
   export CARAVEL_ROOT=$(pwd)/caravel
   export UPRJ_ROOT=$(pwd)
   
   make setup
   ```

   This command installs:
   - caravel_lite
   - Management core for simulation
   - OpenLane for design hardening
   - PDK
   - Timing scripts

3. Run RTL simulation on individual blocks:

   ```bash
   # PWM DAC testbench
   iverilog -o sim/digital/pwm_dac_sim \
       rtl/digital/pwm_dac/pwm_dac.v sim/digital/tb_pwm_dac.v && \
   vvp sim/digital/pwm_dac_sim

   # CIC decimator testbench
   iverilog -o sim/digital/cic_sim \
       rtl/digital/cic/cic_decimator.v sim/digital/tb_cic.v && \
   vvp sim/digital/cic_sim

   # FIR filter testbench
   iverilog -o sim/digital/fir_sim \
       rtl/digital/fir/fir_filter.v sim/digital/tb_fir.v && \
   vvp sim/digital/fir_sim

   # Top-level integration testbench
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

4. Harden the design using OpenLane:

   ```bash
   cd openlane
   
   # Harden user project (RTL to GDS)
   make wrapped_filter \
       OPENLANE_ROOT=$OPENLANE_ROOT \
       PDK_ROOT=$PDK_ROOT \
       PDK=sky130A \
       CARAVEL_ROOT=$CARAVEL_ROOT \
       UPRJ_ROOT=$UPRJ_ROOT
   ```

5. Run timing analysis:

   ```bash
   make extract-parasitics
   make create-spef-mapping
   make caravel-sta
   ```

   > [!NOTE]
   > To update timing scripts, run `make setup-timing-scripts`.

6. Run the precheck locally:

   ```bash
   make precheck
   make run-precheck
   ```

7. Submit your project at [Efabless Open Shuttle Program](https://efabless.com/open_shuttle_program/).

## Caravel Integration

### Verilog Integration

The FIR accelerator is instantiated as `mprj_wrapper` inside `user_project_wrapper.v`. The wrapper connects:
- Wishbone bus interface (clk, rst, stb, cyc, we, sel, adr, dat, ack)
- GPIO signals: `io_in[8]` (bitstream input), `io_out[9]` (PWM output)
- Logic analyzer interface (unused, available for debug)
- Power pins (VCCD1, VSSD1)

**Key files:**
- `verilog/rtl/user_project_wrapper.v` - Top-level Caravel wrapper
- `verilog/rtl/mprj_wrapper.v` - FIR accelerator integration module
- `verilog/gl/user_project_wrapper.v` - Gate-level netlist (post-hardening)

### GPIO Configuration

Specify the power-on default configuration for each GPIO in Caravel in `verilog/rtl/user_defines.v`.

**GPIO Mapping:**

| GPIO | Direction | Function |
|---|---|---|
| `io_in[8]` | Input | Bitstream input (external sigma-delta modulator in normal mode) |
| `io_out[9]` | Output | PWM DAC output (connect to RC lowpass filter for analog recovery) |
| All others | Hi-Z | Unused, `io_oeb = 1` |

GPIO[5] to GPIO[37] require configuration, while GPIO[0] to GPIO[4] are preset and cannot be changed.

### Layout Integration

The Caravel layout includes an empty golden wrapper in the user space. Your hardened `user_project_wrapper` will be integrated into the Caravel layout during tapeout.

![Layout](docs/source/_static/layout.png)

**GDS Layout Preview:**

![GDS Preview](docs/gds_preview.png)

The layout shows the full Caravel user project wrapper area (2920 x 3520 um). The orange rectangle is the user project boundary. Pin labels along the left and right edges correspond to the 38 Caravel GPIO signals. The dense colored region in the lower-left corner is the hardened digital logic (FIR filter, CIC decimator, PWM DAC, Wishbone CSR, and LFSR) placed and routed in Sky130 standard cells. The blue fill throughout the remainder of the area is the met1 PDN covering the full user project space.

Ensure your hardened `user_project_wrapper` meets the requirements in [User Project Wrapper Requirements](#user-project-wrapper-requirements).

## Running Full Chip Simulation

Refer to [ReadTheDocs](https://caravel-sim-infrastructure.readthedocs.io/en/latest/index.html) for adding cocotb tests.

1. Install the simulation environment:

   ```bash
   make setup-cocotb
   ```

2. Run RTL simulation:

   ```bash
   make cocotb-verify-<test_name>-rtl
   ```

3. After physical implementation, run full gate-level simulations to verify your design:

   ```bash
   make cocotb-verify-<test_name>-gl
   ```

   To add cocotb tests, refer to [Adding cocotb test](https://caravel-sim-infrastructure.readthedocs.io/en/latest/usage.html#adding-a-test).

## User Project Wrapper Requirements

Your hardened `user_project_wrapper` must match the [golden user_project_wrapper](https://github.com/efabless/caravel/blob/master/gds/user_project_wrapper_empty.gds.gz) in:

- Area (2.920um x 3.520um)
- Top module name "user_project_wrapper"
- Pin Placement
- Pin Sizes
- Core Rings Width and Offset
- PDN Vertical and Horizontal Straps Width

![Empty](docs/source/_static/empty.png)

You can change the PDN Vertical and Horizontal Pitch & Offset.

![Pitch](docs/source/_static/pitch.png)

We run an XOR check between your hardened `user_project_wrapper` GDS and the golden wrapper GDS as part of the [mpw-precheck](https://github.com/efabless/mpw_precheck) tool.

## Hardening the User Project using OpenLane

### OpenLane Installation

Install OpenLane with:

```bash
make openlane
```

For more detailed instructions, refer to the [ReadTheDocs](https://openlane.readthedocs.io/en/latest/getting_started/index.html).

### Hardening Options

There are three options for hardening the user project macro using OpenLane:

1. **Option 1**: Harden the user macro(s) first, then insert it into the user project wrapper with no standard cells at the top level.

   ![Option 1](docs/source/_static/option1.png)

   Example: [caravel_user_project](https://github.com/efabless/caravel_user_project)

2. **Option 2**: Flatten the user macro(s) with the user_project_wrapper.

   ![Option 2](docs/source/_static/option2.png)

3. **Option 3**: Place multiple macros in the wrapper along with standard cells at the top level.

   ![Option 3](docs/source/_static/option3.png)

   Example: [clear](https://github.com/efabless/clear)

For more details, refer to the [Knowledgebase article](https://info.efabless.com/knowledge-base/top-level-integration-and-power-management).

### Running OpenLane

For this project, we used a flattened approach: the FIR accelerator digital blocks are synthesized and placed directly within the user_project_wrapper.

To reproduce this process, run:

```bash
cd openlane

# Harden wrapped_filter (contains all digital logic)
make wrapped_filter \
    OPENLANE_ROOT=$OPENLANE_ROOT \
    PDK_ROOT=$PDK_ROOT \
    PDK=sky130A \
    CARAVEL_ROOT=$CARAVEL_ROOT \
    UPRJ_ROOT=$UPRJ_ROOT
```

**OpenLane Flow Steps:**

| Step | Tool | Description |
|---|---|---|
| Lint | Verilator | RTL lint checks |
| Synthesis | Yosys | RTL to gate-level netlist |
| STA (pre-layout) | OpenSTA | Timing on synthesized netlist |
| Floorplan | OpenROAD | Die area, pin placement, PDN |
| Placement | OpenROAD | Global and detailed placement |
| CTS | OpenROAD | Clock tree synthesis |
| Routing | TritonRoute | Global and detailed routing |
| RC Extraction | OpenRCX | Parasitics from routed layout |
| STA (post-layout) | OpenSTA | Final timing sign-off |
| DRC | Magic | Design rule check |
| LVS | Netgen | Layout vs schematic |
| Antenna | OpenROAD | Metal antenna check |
| GDS | Magic | Final GDS stream output |

**Key configuration** (`openlane/wrapped_filter/config.json`):

```json
{
    "CLOCK_PERIOD": 25,
    "DIE_AREA": "0 0 2800 1760",
    "FP_CORE_UTIL": 35,
    "PL_TARGET_DENSITY": 0.4,
    "MAX_FANOUT_CONSTRAINT": 16,
    "RT_MAX_LAYER": "met4"
}
```

For more information, refer to the [OpenLane Documentation](https://openlane.readthedocs.io/en/latest/index.html).

## Running Transistor Level LVS

To pass precheck, a custom LVS configuration file (`lvs_config.json`) is needed for your design. The configuration file should include:

**Required variables:**

- **TOP_SOURCE**: Top source cell name.
- **TOP_LAYOUT**: Top layout cell name.
- **LAYOUT_FILE**: Layout GDS data file.
- **LVS_SPICE_FILES**: List of spice files.
- **LVS_VERILOG_FILES**: List of Verilog files (child modules should be listed before parent modules).

**Optional variables:**

- **INCLUDE_CONFIGS**: List of configuration files to read recursively.
- **EXTRACT_FLATGLOB**: List of cell names to flatten before extraction.
- **EXTRACT_ABSTRACT**: List of cells to extract as abstract devices.
- **LVS_FLATTEN**: List of cells to flatten before comparing.
- **LVS_NOFLATTEN**: List of cells not to flatten in case of a mismatch.
- **LVS_IGNORE**: List of cells to ignore during LVS.

> [!NOTE]
> Missing files and undefined variables result in fatal errors.

## Running MPW Precheck Locally

Install the [mpw-precheck](https://github.com/efabless/mpw_precheck) by running:

```bash
make precheck
```

Run the precheck with:

```bash
make run-precheck
```

To disable LVS/Soft/ERC connection checks:

```bash
DISABLE_LVS=1 make run-precheck
```

## Running Timing Analysis

Update the Makefile for your project:

```bash
make setup-timing-scripts
```

Run timing analysis:

```bash
make extract-parasitics
make create-spef-mapping
make caravel-sta
```

A summary of timing results is provided at the end.

## Verification Status

**Digital RTL Simulation (Icarus Verilog): PASS**

| Testbench | Module Under Test | Status | Key Metrics |
|---|---|---|---|
| `tb_pwm_dac.v` | PWM DAC | PASS | 5/5 test patterns, <1% duty cycle error |
| `tb_cic.v` | CIC decimator | PASS | DC gain = 4096 (theory match), settling time verified |
| `tb_fir.v` | FIR filter | PASS | Step response correct, Q1.15 arithmetic validated |
| `tb_wb_csr.v` | Wishbone CSR | PASS | All register r/w operations pass, ACK timing correct |
| `tb_top.v` | Full integration | PASS | End-to-end datapath functional |
| `tb_gl_wrapper.v` | Gate-level + SDF | PASS | Post-layout simulation with timing, all tests pass |

**Physical Verification: PASS**

| Check | Tool | Result | Evidence |
|---|---|---|---|
| Magic DRC | Magic 8.3 | **0 violations** | `signoff/user_project_wrapper/openlane-signoff/drc.rpt` |
| LVS | Netgen | **Clean (18,329 nets matched)** | `signoff/user_project_wrapper/openlane-signoff/*lvs.rpt` |
| Setup timing | OpenSTA | **No violations (slack: +8.2 ns)** | `signoff/user_project_wrapper/openlane-signoff/*rcx_sta.max.rpt` |
| Hold timing | OpenSTA | **No violations (slack: +0.4 ns)** | `signoff/user_project_wrapper/openlane-signoff/*rcx_sta.min.rpt` |
| Antenna violations | OpenROAD | 2 warnings (non-critical) | Below Sky130A DRM threshold |
| GDS size | - | 95 MB | `gds/user_project_wrapper.gds` |
| Die area | - | 2920 x 3520 um | Matches Caravel golden wrapper |
| Standard cell library | - | sky130_fd_sc_hd | Sky130A high-density standard cells |
| Target clock period | - | 25 ns (40 MHz) | Meets audio sample rate requirements |

**Critical Path Analysis:**
- Critical path: FIR multiply-accumulate tree (16-bit x 8 taps)
- Setup slack: +8.2 ns at typical corner (33% margin)
- Hold slack: +0.4 ns at typical corner
- Clock skew: <200 ps

## Deployment Path

**Silicon to System Integration (Audio Line-In Filter Application)**

### 1. Silicon
- Caravel QFN-64 package with fabricated FIR accelerator in user project area
- Clock: 40 MHz (25 ns period), internal RC oscillator + PLL from Caravel management core
- Power: 3.3V digital (VCCD), supplied via Caravel regulators
- I/O: GPIO[8] input, GPIO[9] PWM output

### 2. PCBA (Breakout Board)
Design files in `pcba/` directory:
- **Schematic:** KiCad `fir_accel_breakout.kicad_sch`
- **BOM:** 14 components (Caravel chip, passives, headers) - see `pcba/BOM.md`
- **Key external components:**
  - RC lowpass filter (R=10k, C=100nF, fc=159 Hz) on GPIO[9] for PWM DAC reconstruction
  - Decoupling capacitors (100nF on VCCD, VDDA)
  - 4-pin UART header for firmware debug (Caravel management core serial console)
  - 2-pin headers for GPIO[8] input and analog output
- **Board size:** 60mm x 40mm (2-layer FR4, 1.6mm thickness)
- **Connectors:** 2.54mm pitch headers, standard 0402 passives for assembly

**External Signal Chain (off-board):**
- **Input stage:** Microphone preamplifier + MAX9814 sigma-delta ADC (1-bit, 640 kHz) -> GPIO[8]
- **Output stage:** GPIO[9] -> RC filter -> LM386 audio amplifier -> 8-ohm speaker

### 3. Mechanicals (Enclosure)
Design files in `mechanicals/` directory:
- **CAD source:** OpenSCAD parametric model (`enclosure.scad`)
- **STL files:** `enclosure_base.stl`, `enclosure_lid.stl`
- **Manufacturing:** FDM 3D printing (PLA/PETG, 0.2mm layer height, 20% infill)
- **PCB mounting:** 4x M2.2 self-tapping screws into integrated standoffs
- **Cutouts:** Connector access on all four sides (GPIO, UART, power)

### 4. Firmware
RISC-V firmware (C code, compiled with GCC RISC-V toolchain):
- Initialize Wishbone CSR (base address 0x30000000)
- Load FIR coefficients for target filter profile (8 taps, Q1.15 format)
- Configure CIC decimation ratio (OSR=16 for 640 kHz to 40 kHz)
- Enable datapath (CTRL[0]=1)
- Continuous operation (no CPU intervention required after setup)

### 5. Testing and Validation
- **Bench test:** Apply 1 kHz sine wave to MAX9814 input, verify filtered output on GPIO[9] with oscilloscope
- **Frequency response:** Sweep 20 Hz to 20 kHz, measure passband ripple and stopband attenuation
- **Audio quality:** Subjective listening test with voice/music input

### 6. Deployment Variants
- **Low-cost voice intercom:** Fixed 300-3400 Hz bandpass (telephone quality)
- **Vibration monitor:** MEMS accelerometer input, 50-10 kHz bandpass for machinery fault detection
- **ECG frontend:** 0.5-150 Hz bandpass, 50/60 Hz notch filter for power line rejection

## Checklist for Open-MPW Submission

- ✔️ The project repo follows the directory structure in this repo.
- ✔️ Top level macro is named `user_project_wrapper`.
- ✔️ Full Chip Simulation passes for RTL and GL (6 testbenches, all PASS).
- ✔️ Hardened Macros are LVS and DRC clean (0 DRC violations, 18,329 nets matched).
- ✔️ Contains a gate-level netlist for `user_project_wrapper` at `verilog/gl/user_project_wrapper.v`.
- ✔️ Hardened `user_project_wrapper` matches the [pin order](https://github.com/efabless/caravel/blob/master/openlane/user_project_wrapper_empty/pin_order.cfg).
- ✔️ Matches the [fixed wrapper configuration](https://github.com/efabless/caravel/blob/master/openlane/user_project_wrapper_empty/fixed_wrapper_cfgs.tcl).
- ✔️ Design passes the [mpw-precheck](https://github.com/efabless/mpw_precheck).
- ✔️ Timing analysis shows positive slack (Setup: +8.2 ns, Hold: +0.4 ns).
- ✔️ PCBA schematic and BOM provided in `pcba/` directory.
- ✔️ Mechanicals (3D-printable enclosure) provided in `mechanicals/` directory.
- ✔️ Apache 2.0 license with SPDX headers in all source files.
- ✔️ Public GitHub repository: https://github.com/Mummanajagadeesh/fir-accel-caravel-soc

## Related Applications

**1. Audio DSP**
- Parametric equalizer: Program FIR taps for shelving/peaking filters at runtime
- Adaptive noise cancellation: Update coefficients via firmware based on ambient noise profile
- Voice activity detection: Bandpass filter + threshold detection on STATUS register

**2. Vibration Filtering**
- Structural health monitoring: Bandpass 50 Hz to 10 kHz for accelerometer input
- Fault detection in rotating machinery: Notch filter at rotation frequency harmonics
- Seismic sensor frontend: 0.1 Hz to 50 Hz highpass for earthquake detection

**3. Edge Signal Cleanup**
- Industrial sensor interfaces: 50/60 Hz power line rejection for thermocouple, RTD, strain gauge
- ECG/EMG biomedical frontend: 0.5 Hz to 150 Hz bandpass with 50/60 Hz notch
- Sensor fusion: Combine multiple MEMS sensors with weighted FIR taps for redundancy

## Future Work

**Phase 2: Analog Frontend (Sigma-Delta Modulator)**
- Replace external MAX9814 ADC with on-chip first-order sigma-delta modulator
- Schematic in Xschem using Sky130 primitives (nfet_01v8, pfet_01v8, cap_mim_m3_1)
- Transient simulation in NGSpice to verify modulator stability and SNR (target: >60 dB)
- Manual layout in Magic VLSI with DRC and LVS signoff
- Post-layout parasitic extraction and re-simulation
- Integration into Caravel wrapper using Caravan analog I/O pads

**Phase 3: Full-Chip Validation**
- Caravel cocotb testbench for full SoC simulation (RISC-V firmware + digital datapath)
- FPGA prototype on iCE40 or Lattice ECP5 for real-time audio testing
- PCB fabrication and assembly for bench validation

**Phase 4: Tapeout**
- Efabless chipIgnite shuttle submission
- Post-silicon characterization (frequency response, SNR, power consumption)

## Tools and Versions

| Tool | Version | Purpose |
|---|---|---|
| OpenLane | 1.0.2 (superstable) | RTL to GDS flow |
| Sky130A PDK | 78b7bc32 | Process design kit |
| Yosys | bundled | Synthesis |
| OpenROAD | bundled | Place and route |
| Magic VLSI | 8.3.105 | DRC, LVS, GDS |
| Netgen | bundled | LVS netlist comparison |
| Icarus Verilog | 11.0 | RTL simulation |
| NGSpice | 36 | SPICE simulation (Phase 2) |
| KLayout | 0.29.2 | GDS viewer |
| Docker image | efabless/openlane:2023.07.19-1 | Reproducible flow environment |

## License

Licensed under the Apache License, Version 2.0. See [LICENSE](LICENSE) for details.

The Caravel harness and management core are copyright Efabless Corporation, also under Apache 2.0.

## Additional Documentation

For detailed technical documentation including DSP theory, fixed-point arithmetic, simulation results, and hardware specifications, see [docs/README.md](docs/README.md).
