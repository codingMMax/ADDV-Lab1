# Alternating Circuit Testbench

## Overview

`tb_alternating_circuit.sv` acts as both the input producer and output
consumer. It drives `write_en` and `read_en`, loads input data from `.dat`
files, and compares the output against parity-specific reference arrays.

The testbench uses one 10 ns clock and an active-low reset. Read requests use a
repeating `1111111100` pattern, giving eight requests per ten clock cycles.

## Input data

Each data file contains 80 values: 40 even and 40 odd.

- `random_1.dat`: first random ordering
- `random_2.dat`: second random ordering
- `even_then_odd.dat`: 40 even values followed by 40 odd values
- `odd_then_even.dat`: 40 odd values followed by 40 even values

When the files are loaded, the testbench separates their values into expected
even and odd arrays while preserving the order within each parity.

## Test cases

### Case 3

```text
cycles 0-79:    write random_1.dat
cycles 80-99:   idle
cycles 100-179: write random_2.dat
cycles 180-199: idle
```

### Case 4

```text
cycles 0-19:    idle
cycles 20-99:   write even_then_odd.dat
cycles 100-179: write odd_then_even.dat
cycles 180-199: idle
```

The combined Case 4 parity sequence is:

```text
40 even -> 80 odd -> 40 even
```

Read requests continue after the 200 input cycles until all 160 expected
outputs have been read.

## Checks

The testbench checks the following conditions:

- the simulation completes before the timeout
- neither the even FIFO nor the odd FIFO asserts `full`
- the first successful output is even
- successful outputs alternate between even and odd
- even outputs preserve the input order of the even values
- odd outputs preserve the input order of the odd values
- `data_out` matches the corresponding even or odd reference value

The test prints `PASS` if no check reports an error. Otherwise, it terminates
with a fatal error and reports the total number of errors.
