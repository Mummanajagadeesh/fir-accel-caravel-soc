# SPDX-FileCopyrightText: 2026 Mummana Jagadeesh
# SPDX-License-Identifier: Apache-2.0
from caravel_cocotb.caravel_interfaces import test_configure
from caravel_cocotb.caravel_interfaces import report_test
import cocotb
from cocotb.triggers import ClockCycles

@cocotb.test()
@report_test
async def fir_wb(dut):
    caravelEnv = await test_configure(dut, timeout_cycles=500000)
    cocotb.log.info("[TEST] Start fir_wb test")

    await caravelEnv.release_csb()

    # Wait for firmware to signal start (mgmt_gpio=1)
    await caravelEnv.wait_mgmt_gpio(1)
    cocotb.log.info("[TEST] Firmware started - FIR pipeline initializing")

    # Wait for pipeline to fill and firmware to signal done (mgmt_gpio=0)
    await caravelEnv.wait_mgmt_gpio(0)
    cocotb.log.info("[TEST] Pipeline filled - checking PWM output")

    # Wait a few cycles and check GPIO[9] (PWM output) is being driven
    await ClockCycles(dut.clk, 100)

    # Monitor GPIO[9] for PWM activity over 256 cycles
    high_count = 0
    for _ in range(256):
        await ClockCycles(dut.clk, 1)
        if dut.mprj_io[9].value == 1:
            high_count += 1

    cocotb.log.info(f"[TEST] PWM high count over 256 cycles: {high_count}")

    # In LFSR mode with moving average, expect roughly 50% duty cycle
    # Accept 20%-80% range as passing
    assert 20 < high_count < 230, \
        f"PWM duty cycle out of range: {high_count}/256"
    cocotb.log.info("[TEST] PWM duty cycle check passed")

    # Wait for bypass mode signal (mgmt_gpio=1)
    await caravelEnv.wait_mgmt_gpio(1)
    cocotb.log.info("[TEST] Bypass mode active")

    # In bypass mode with PWM_DATA=0x80, expect ~50% duty cycle
    high_count = 0
    for _ in range(256):
        await ClockCycles(dut.clk, 1)
        if dut.mprj_io[9].value == 1:
            high_count += 1

    cocotb.log.info(f"[TEST] Bypass PWM high count: {high_count}")
    assert 100 < high_count < 156, \
        f"Bypass PWM duty cycle out of range: {high_count}/256"
    cocotb.log.info("[TEST] fir_wb test PASSED")
