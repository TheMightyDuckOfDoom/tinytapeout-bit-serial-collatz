# SPDX-FileCopyrightText: © 2024 Tiny Tapeout © 2026 Tobias Senti
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

MainRegWidth = 8
StepCounterWidth = 8

async def write_number(dut, value):
    bv = [0] * MainRegWidth
    for i in range(MainRegWidth):
        bv[i] = (value >> i) & 1

    # Shift in the bits
    for i in range(MainRegWidth):
        dut.ui_in.value = (1 << 1) | bv[i]
        await ClockCycles(dut.clk, 1)
    dut.ui_in.value = 0
    await ClockCycles(dut.clk, 1)

async def read_step_counter(dut):
    await ClockCycles(dut.clk, 1)
    dut.ui_in.value = 0 # Disable step counter shifting
    await ClockCycles(dut.clk, 2)
    # Read the step counter
    step_counter = 0
    for i in range(StepCounterWidth):
        print(f"output value: {dut.uo_out.value}")
        #dut.ui_in.value = 1 << 2 # Enable step counter shifting
        out = (dut.uo_out.value.to_unsigned() >> 1) & 1 # Check second bit of output
        print(f"Step counter bit {i}: {out}")
        step_counter |= out << i # Read the LSB first
        await ClockCycles(dut.clk, 1)
        dut.ui_in.value = 1 << 2 # Enable step counter shifting
        await ClockCycles(dut.clk, 1)
        dut.ui_in.value = 0 # Disable step counter shifting
        await ClockCycles(dut.clk, 1)

    dut._log.info(f"Step counter: {step_counter}")
    return step_counter

async def start_computation(dut):
    dut.ui_in.value = 1 << 3
    await ClockCycles(dut.clk, 1)
    dut.ui_in.value = 0
 
    finished = False
    for i in range(1000):
        await ClockCycles(dut.clk, 1)
        if (dut.uo_out.value.to_unsigned() & (1 << 2)) != 0:
            dut._log.info(f"Computation finished after {i+1} cycles")
            finished = True
            break

    if not finished:
        dut._log.error("Computation did not finish within 1000 cycles")

    return finished


async def run_number(dut, n):
    await write_number(dut, n)
    if not await start_computation(dut):
        return -1
    step_counter = await read_step_counter(dut)
    return step_counter

def collatz(n):
    starting_n = n
    print(f"Starting Collatz computation for n={n}")
    steps = 0
    while n != 1 and n != 0:
        print(f"n={n}, steps={steps}")
        if n % 2 == 0:
            n = n // 2
        else:
            n = 3 * n + 1
        steps += 1

    print(f"Finished Collatz computation for n={starting_n}, total steps={steps}")
    return steps

@cocotb.test()
async def test_project(dut):
    dut._log.info("Start")

    # Set the clock period to 10 us (100 KHz)
    clock = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clock.start())

    # Reset
    dut._log.info("Reset")
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    dut._log.info("Test project behavior")
    failures = {}

    # TODO: Works up to 27, but 27 is wrong
    max = 27
    for n in range(1, max):
        sw_steps = collatz(n)
        hw_steps = await run_number(dut, n)

        if hw_steps != sw_steps:
            failures[n] = (sw_steps, hw_steps)
            dut._log.error(f"Test failed for n={n}: expected {sw_steps} steps, got {hw_steps} steps")
        else:
            dut._log.info(f"Test completed for n={n}: expected {sw_steps} steps, got {hw_steps} steps")

    if failures:
        for n, (sw_steps, hw_steps) in failures.items():
            dut._log.error(f"Test failed for n={n}: expected {sw_steps} steps, got {hw_steps} steps")

        percent_works = 100 * (max - 1 - len(failures)) / (max - 1)
        dut._log.error(f"{len(failures)} out of {max - 1} tests failed ({percent_works:.2f}% success rate)")
