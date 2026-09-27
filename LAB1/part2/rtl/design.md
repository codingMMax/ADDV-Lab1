# Alternating Circuit Design

## Overview

`alternating_circuit` stores incoming 8-bit values in separate even and odd
FIFOs. On a read request, it outputs the oldest even and odd values in an
alternating order, beginning with an even value.

The external interface contains the following signals:

- `clock`: common clock for the circuit and both FIFOs
- `reset`: active-low reset
- `data_in`: 8-bit input data
- `write_en`: input write request
- `data_out`: registered 8-bit output data
- `read_en`: output read request

## Module hierarchy

```text
alternating_circuit
├── store_input
│   ├── even_async_fifo
│   └── odd_async_fifo
└── produce_sorted_output
```

### `alternating_circuit`

This is the top-level module. It connects the external
`alternating_circuit_interface` to `store_input` and
`produce_sorted_output`.

### `store_input`

`store_input` checks `data_in[0]` when `write_en` is asserted.

- `data_in[0] == 0`: write to the even FIFO
- `data_in[0] == 1`: write to the odd FIFO

Each FIFO has `ADDR_W=6`, giving a depth of 64 entries. A write is blocked
internally if the selected FIFO is full.

### `produce_sorted_output`

This module contains a two-state FSM:

- `EVEN_STATE`: wait for and read an even value
- `ODD_STATE`: wait for and read an odd value

The FSM starts in `EVEN_STATE`. A state transition occurs only when `read_en`
is asserted and the selected FIFO is not empty. If the selected FIFO is empty,
the FSM waits in the current state.

On a successful read, the FIFO's show-ahead `rdata` is stored in the registered
`data_out`, and the FSM changes to the opposite parity.

### `async_fifo`

The existing asynchronous FIFO is used for both parity queues. It contains:

- `fifo_mem`: memory array with synchronous write and show-ahead read
- `wptr_full`: binary/Gray write pointer and `full`/`almost_full` logic
- `rptr_empty`: binary/Gray read pointer and `empty`/`almost_empty` logic
- two-stage Gray-pointer synchronizers for each clock-domain crossing

Although Part 2 connects both FIFO clock domains to the same external clock,
the original asynchronous FIFO structure is reused without modification.
