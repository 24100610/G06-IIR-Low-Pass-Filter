# G06 IIR Low-Pass Filter

## Overview

This project implements a first-order IIR low-pass filter using SystemVerilog.

## Filter equation

The intended filter equation is:

\[
y[n] = \frac{x[n] + y[n-1]}{2}
\]

where:
- `x[n]` is the current input sample.
- `y[n-1]` is the previous output sample.
- `y[n]` is the current output sample.

## Project contents

- `04_IMPLEMENTATION/rtl/g06_iir_half.sv`: RTL implementation.
- `05_VERIFICATION/testbench/g06_tb.sv`: Testbench for RTL verification.

## Tools

- SystemVerilog
- Icarus Verilog
- GTKWave
- Yosys
- Sky130A / LibreLane physical design flow

## Verification

The testbench is used to verify the filter behavior through simulation. See the testbench and simulation results for details.
