// SPDX-FileCopyrightText: 2026 Mummana Jagadeesh
// SPDX-License-Identifier: Apache-2.0
#include <firmware_apis.h>

#define FIR_BASE     0x30000000
#define REG_CTRL     (*(volatile uint32_t*)(FIR_BASE + 0x00))
#define REG_OSR      (*(volatile uint32_t*)(FIR_BASE + 0x04))
#define REG_COEFF_A  (*(volatile uint32_t*)(FIR_BASE + 0x08))
#define REG_COEFF_D  (*(volatile uint32_t*)(FIR_BASE + 0x0C))
#define REG_STATUS   (*(volatile uint32_t*)(FIR_BASE + 0x10))
#define REG_PWM      (*(volatile uint32_t*)(FIR_BASE + 0x14))

void main() {
    ManagmentGpio_outputEnable();
    ManagmentGpio_write(0);
    enableHkSpi(0);

    // GPIO[8]=input, GPIO[9]=output
    GPIOs_configure(8, GPIO_MODE_USER_STD_INPUT_NOPULL);
    GPIOs_configure(9, GPIO_MODE_USER_STD_OUT_MONITORED);
    GPIOs_loadConfigs();
    User_enableIF();

    // Signal start
    ManagmentGpio_write(1);

    // Soft reset
    REG_CTRL = 0x08;
    for (volatile int i = 0; i < 100; i++);
    REG_CTRL = 0x00;

    // Set OSR=16
    REG_OSR = 16;

    // Load moving average coefficients (h[k]=0x1000 = 0.125 in Q1.15)
    for (int i = 0; i < 8; i++) {
        REG_COEFF_A = i;
        REG_COEFF_D = 0x1000;
    }

    // Enable with LFSR test source
    REG_CTRL = 0x11; // enable=1, use_lfsr=1

    // Wait for pipeline to fill
    for (volatile int i = 0; i < 5000; i++);

    // Signal done — cocotb monitors this
    ManagmentGpio_write(0);

    // Test bypass mode: direct PWM = 0x80 (50%)
    REG_PWM  = 0x80;
    REG_CTRL = 0x03; // enable=1, bypass_fir=1

    for (volatile int i = 0; i < 1000; i++);

    // Signal complete
    ManagmentGpio_write(1);

    while(1);
}
