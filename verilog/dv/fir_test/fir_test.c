// SPDX-FileCopyrightText: 2026 Mummana Jagadeesh
// SPDX-License-Identifier: Apache-2.0
//
// FIR Accelerator SoC - RISC-V Firmware
// Programs the FIR filter with lowpass coefficients and enables the pipeline

#include <defs.h>

// Base address of our Wishbone CSR block
#define FIR_BASE  0x30000000

// Register offsets
#define REG_CTRL        (*(volatile uint32_t*)(FIR_BASE + 0x00))
#define REG_OSR         (*(volatile uint32_t*)(FIR_BASE + 0x04))
#define REG_COEFF_ADDR  (*(volatile uint32_t*)(FIR_BASE + 0x08))
#define REG_COEFF_DATA  (*(volatile uint32_t*)(FIR_BASE + 0x0C))
#define REG_STATUS      (*(volatile uint32_t*)(FIR_BASE + 0x10))
#define REG_PWM_DATA    (*(volatile uint32_t*)(FIR_BASE + 0x14))

// CTRL bits
#define CTRL_ENABLE     (1 << 0)
#define CTRL_BYPASS_FIR (1 << 1)
#define CTRL_BYPASS_CIC (1 << 2)
#define CTRL_SOFT_RST   (1 << 3)
#define CTRL_USE_LFSR   (1 << 4)

// Q1.15 fixed-point conversion
#define Q15(x) ((int16_t)((x) * 32768.0))

// 8-tap Hamming-windowed lowpass FIR coefficients
// Cutoff = fs/8, normalized to Q1.15
// h = [0.0095, 0.0635, 0.2165, 0.3605, 0.3605, 0.2165, 0.0635, 0.0095]
static const uint16_t fir_coeffs[8] = {
    Q15(0.0095),   // h[0]
    Q15(0.0635),   // h[1]
    Q15(0.2165),   // h[2]
    Q15(0.3605),   // h[3]
    Q15(0.3605),   // h[4]
    Q15(0.2165),   // h[5]
    Q15(0.0635),   // h[6]
    Q15(0.0095),   // h[7]
};

static void load_fir_coeffs(const uint16_t *coeffs, int n_taps)
{
    int i;
    for (i = 0; i < n_taps; i++) {
        REG_COEFF_ADDR = i;
        REG_COEFF_DATA = coeffs[i];  // write triggers load
    }
}

static void fir_pipeline_init(void)
{
    // Soft reset
    REG_CTRL = CTRL_SOFT_RST;
    // Small delay
    for (volatile int i = 0; i < 100; i++);
    REG_CTRL = 0;

    // Set OSR = 16
    REG_OSR = 16;

    // Load lowpass FIR coefficients
    load_fir_coeffs(fir_coeffs, 8);
}

void main(void)
{
    // Configure Caravel IO
    // GPIO[9] = output (PWM DAC)
    // GPIO[8] = input  (bitstream)
    reg_mprj_io_9  = GPIO_MODE_USER_STD_OUTPUT;
    reg_mprj_io_8  = GPIO_MODE_USER_STD_INPUT_NOPULL;

    // Apply GPIO config
    reg_mprj_xfer = 1;
    while (reg_mprj_xfer == 1);

    // Initialize FIR pipeline
    fir_pipeline_init();

    // --- Mode 1: Normal operation ---
    // Enable pipeline with GPIO[8] as bitstream input
    REG_CTRL = CTRL_ENABLE;

    // Wait for pipeline to fill (OSR * N_STAGES * N_TAPS cycles minimum)
    for (volatile int i = 0; i < 10000; i++);

    // --- Mode 2: Test mode with LFSR ---
    // Switch to internal LFSR for self-test (no external hardware needed)
    REG_CTRL = CTRL_ENABLE | CTRL_USE_LFSR;

    // Run for a while
    for (volatile int i = 0; i < 100000; i++);

    // --- Mode 3: Direct PWM bypass ---
    // Output a fixed 50% duty cycle (1.65V on RC-filtered output)
    REG_PWM_DATA = 0x80;
    REG_CTRL = CTRL_ENABLE | CTRL_BYPASS_FIR;

    // Hold here — output stable PWM on GPIO[9]
    while (1) {
        // Optionally: sweep PWM value for a sawtooth output
        // for (uint8_t v = 0; v < 255; v++) {
        //     REG_PWM_DATA = v;
        //     for (volatile int i = 0; i < 1000; i++);
        // }
    }
}
