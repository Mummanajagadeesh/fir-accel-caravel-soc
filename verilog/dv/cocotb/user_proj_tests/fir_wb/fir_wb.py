# SPDX-FileCopyrightText: 2026 Mummana Jagadeesh
# SPDX-License-Identifier: Apache-2.0
from caravel_cocotb.caravel_interfaces import test_configure
from caravel_cocotb.caravel_interfaces import report_test
import cocotb
from cocotb.triggers import ClockCycles, Timer

@cocotb.test()
@report_test
async def fir_wb(dut):
    caravelEnv = await test_configure(dut, timeout_cycles=500000)
    cocotb.log.info("[TEST] Start fir_wb test")

    await caravelEnv.release_csb()

    # Wait for firmware to signal start (mgmt_gpio=1)
    await caravelEnv.wait_mgmt_gpio(1)
    cocotb.log.info("[TEST] Firmware started - FIR pipeline initializing")

    # Wait for pipeline done signal (mgmt_gpio=0)
    await caravelEnv.wait_mgmt_gpio(0)
    cocotb.log.info("[TEST] Pipeline filled")

    # Wait a bit then check bypass mode signal
    await caravelEnv.wait_mgmt_gpio(1)
    cocotb.log.info("[TEST] Bypass mode active - fir_wb PASSED")
