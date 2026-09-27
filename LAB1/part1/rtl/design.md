# Async FIFO — Design Spec (Lab 1, Part I)

Implementation spec for `rtl/async_fifo.sv`. Everything here is a plan: write the
modules yourself, then verify with `make lint` / `make compile`.

## 1. Parameters and conventions

| Parameter | Value | Notes |
|---|---|---|
| `DATA_WIDTH` | 8 | RTL default |
| `ADDR_W` | 4 | Address bits |
| `DEPTH` | `1 << ADDR_W` = 16 | Must be a power of 2 for gray-code pointers |
| `PTR_W` | `ADDR_W + 1` = 5 | Pointers carry one extra MSB for wrap detection |

- `almost_full` asserts when occupancy >= `3*DEPTH/4` = **12**.
- `almost_empty` asserts when occupancy <= `DEPTH/4` = **4**.
- Consequence: `empty` implies `almost_empty`, `full` implies `almost_full`.
- Style: `always_ff` / `always_comb` only, `logic` everywhere, explicit named
  port connections on every instantiation.

## 2. Interface (already written: `rtl/fifo_interface.sv`)

Type `fifo_interface #(DATA_WIDTH, ADDR_W, DEPTH)` with constructor ports
`wr_clk, rd_clk, wrst_n, rrst_n`; signals `wr_en, wdata, full, almost_full,
rd_en, rdata, empty, almost_empty`; modports `fifo_side` (design view) and
`tb_side` (testbench view).

Usage in the TB (already written):

```systemverilog
fifo_interface #(.DATA_WIDTH(8), .ADDR_W(4)) fifo_bus ( ... );
async_fifo #(.DATA_WIDTH(8), .ADDR_W(4)) async_fifo_inst (.fifo_port(fifo_bus.fifo_side));
```

Top module header:

```systemverilog
module async_fifo #(
    parameter int DATA_WIDTH = 8,
    parameter int ADDR_W     = 4
) (
    fifo_interface.fifo_side fifo_port
);
```

## 3. Block diagram

```
┌──────────────────────────────────── async_fifo (top) ────────────────────────────────────┐
│                                                                                          │
│   ┌────────────────────────┐                           ┌────────────────────────┐        │
│   │       wptr_full        │                           │       rptr_empty       │        │
│   │     (write domain)     │                           │      (read domain)     │        │
│   │────────────────────────│                           │────────────────────────│        │
│   │ in : wclk, wrst_n      │                           │ in : rclk, rrst_n      │        │
│   │      wr_en, rgray_sync │                           │      rd_en, wgray_sync │        │
│   │ out: waddr, wgray,     │                           │ out: raddr, rgray,     │        │
│   │      full, almost_full │                           │      empty,almost_empty│        │
│   └───────────┬────────────┘                           └────────────┬───────────┘        │
│               │ waddr                                        raddr  │                    │
│               └───────────────────────┬───────────────────────┬─────┘                    │
│                                       ▼                       ▼                          │
│        ┌───────────────────────────────────────────────────────────────────┐             │
│        │                             fifo_mem                              │             │
│        │   mem[DEPTH] × DATA_WIDTH                                         │             │
│        │   write @wclk when (wr_en && !full)                               │             │
│        │   async read: rdata = mem[raddr]  ──►  fifo_port.rdata            │             │
│        └───────────────────────────────────────────────────────────────────┘             │
│                                                                                          │
│        ┌───────────────────────────────────────────────────────────────────┐             │
│        │                    CDC synchronizers (2FF each)                   │             │
│        │   read → write :  rgray ──► rgray1/2 (wclk) ──► rgray_sync        │             │
│        │   write → read :  wgray ──► wgray1/2 (rclk) ──► wgray_sync        │             │
│        └───────────────────────────────────────────────────────────────────┘             │
│                                                                                          │
└──────────────────────────────────────────────────────────────────────────────────────────┘
```

Module order inside `async_fifo.sv`: package `fifo_utils` first, then top,
`fifo_mem`, `wptr_full`, `rptr_empty` (order does not affect compilation). The
two 2FF synchronizers are behavioral `always_ff` blocks inside the top module
(section 5.2).

## 4. Top-level wiring plan

Alias interface signals to plain `logic` signals with **continuous
assignments** (the top is the only place that touches the interface). Note: a
declaration initializer (`logic x = y;`) is a one-time assignment at time 0 —
it must NOT be used to alias interface signals.

```systemverilog
logic                  wclk, rclk, wrst_n, rrst_n, wr_en, rd_en;
logic [DATA_WIDTH-1:0] wdata;

assign wclk   = fifo_port.wr_clk;
assign rclk   = fifo_port.rd_clk;
assign wrst_n = fifo_port.wrst_n;
assign rrst_n = fifo_port.rrst_n;
assign wr_en  = fifo_port.wr_en;
assign rd_en  = fifo_port.rd_en;
assign wdata  = fifo_port.wdata;
```

Internal signals. Naming convention: `*bin` = binary pointer, `*gray` = gray
pointer, `*addr` = binary address, and a trailing `1`/`2` = first/second
synchronizer flop stage (e.g. `rgray1`/`rgray2` = `rgray` captured in the
write domain).

| Signal | Width | Producer → Consumer |
|---|---|---|
| `wgray` | `[ADDR_W:0]` gray | `wptr_full.wgray` → top sync (write→read) |
| `rgray` | `[ADDR_W:0]` gray | `rptr_empty.rgray` → top sync (read→write) |
| `rgray1`, `rgray2` | `[ADDR_W:0]` gray | top sync flops (read→write); `rgray2` → `wptr_full.rgray_sync` |
| `wgray1`, `wgray2` | `[ADDR_W:0]` gray | top sync flops (write→read); `wgray2` → `rptr_empty.wgray_sync` |
| `waddr`, `raddr` | `[ADDR_W-1:0]` | pointer blocks → `fifo_mem` |
| `rdata` | `[DATA_WIDTH-1:0]` | `fifo_mem` → `fifo_port.rdata` |
| `full`, `almost_full` | 1 | `wptr_full` → `fifo_port.*` |
| `empty`, `almost_empty` | 1 | `rptr_empty` → `fifo_port.*` |

Instantiation and synchronizers. Submodules use `.*` (implicit named
connections); the two synchronized-pointer inputs have no matching top-level
name, so they are connected explicitly. Interface ports can never use `.*`.

```systemverilog
// Behavioral 2FF synchronizers (the only CDC elements)
always_ff @(posedge wclk or negedge wrst_n) begin   // rgray → write domain
    if (!wrst_n) {rgray2, rgray1} <= '0;
    else         {rgray2, rgray1} <= {rgray1, rgray};
end

always_ff @(posedge rclk or negedge rrst_n) begin   // wgray → read domain
    if (!rrst_n) {wgray2, wgray1} <= '0;
    else         {wgray2, wgray1} <= {wgray1, wgray};
end

fifo_mem #(.DATA_WIDTH(DATA_WIDTH), .ADDR_W(ADDR_W)) u_fifo_mem (.*);

wptr_full #(.ADDR_W(ADDR_W)) u_wptr_full (
    .rgray_sync(rgray2),   // no matching top-level name
    .*
);

rptr_empty #(.ADDR_W(ADDR_W)) u_rptr_empty (
    .wgray_sync(wgray2),   // no matching top-level name
    .*
);

assign fifo_port.full         = full;
assign fifo_port.almost_full  = almost_full;
assign fifo_port.empty        = empty;
assign fifo_port.almost_empty = almost_empty;
assign fifo_port.rdata        = rdata;
```

## 5. Module specs

### 5.1 `fifo_mem #(DATA_WIDTH, ADDR_W)`

| Dir | Name | Width |
|---|---|---|
| in | `wclk` | 1 |
| in | `wr_en` | 1 |
| in | `full` | 1 |
| in | `waddr` | `[ADDR_W-1:0]` |
| in | `wdata` | `[DATA_WIDTH-1:0]` |
| in | `raddr` | `[ADDR_W-1:0]` |
| out | `rdata` | `[DATA_WIDTH-1:0]` |

- Storage: `logic [DATA_WIDTH-1:0] mem [DEPTH];` (`DEPTH = 1 << ADDR_W` localparam).
- Write: `always_ff @(posedge wclk) if (wr_en && !full) mem[waddr] <= wdata;`
- Read: `assign rdata = mem[raddr];` (asynchronous, Cummings style — see section 6).
- No reset port; the array is intentionally not reset (saves hardware).
- Note: DC maps this to flops + read mux for depth 16 — expected and fine.

### 5.2 Synchronizers (behavioral, in the top module)

| Dir | Name | Width |
|---|---|---|
| — | `rgray1`, `rgray2` | `[ADDR_W:0]` gray |
| — | `wgray1`, `wgray2` | `[ADDR_W:0]` gray |

- Two 2FF synchronizers, one per direction, written as `always_ff` blocks in the
  top module (see the instantiation sketch in section 4):
  - read → write: `{rgray2, rgray1} <= {rgray1, rgray};` on `wclk`
  - write → read: `{wgray2, wgray1} <= {wgray1, wgray};` on `rclk`
- Each reset (async assert) clears both of its flops to 0 in its destination domain.
- Only gray pointers cross domains; never synchronize binary pointers.
- These four flops are the only CDC elements and must be marked as such on the
  microarchitecture diagram.

### 5.3 `wptr_full #(ADDR_W)`

| Dir | Name | Width |
|---|---|---|
| in | `wclk`, `wrst_n`, `wr_en` | 1 |
| in | `rgray_sync` | `[ADDR_W:0]` gray (synchronized read pointer) |
| out | `waddr` | `[ADDR_W-1:0]` |
| out | `wgray` | `[ADDR_W:0]` gray (registered gray write pointer) |
| out | `full`, `almost_full` | 1 |

Internal signals: `wbin, wbin_next, wgray_next` (`PTR_W` bits),
`rbin_sync`, `occupancy` (`PTR_W` bits), `full_next`, `almost_full_next`.

Behavior:

- `wbin_next = wbin + (wr_en && !full)`
- `wgray_next = bin2gray(wbin_next)`
- `full_next = (wgray_next == {~rgray_sync[PTR_W-1:PTR_W-2], rgray_sync[PTR_W-3:0]})`
  (Cummings full compare: inverted two MSBs, rest equal)
- `rbin_sync = gray2bin(rgray_sync)`
- `occupancy = wbin_next - rbin_sync` (post-write occupancy; unsigned, range
  0..DEPTH thanks to the extra MSB — same next-state timing as `full`)
- `almost_full_next = (occupancy >= 3*DEPTH/4)`
- Outputs: `waddr = wbin[ADDR_W-1:0]`; `wgray` is the registered gray write pointer.
- Registered on `wclk`: `wbin, wgray, full, almost_full`.
- Reset values: `wbin = 0, wgray = 0, full = 0, almost_full = 0`.
- Uses the shared `fifo_utils` package functions (section 7).

### 5.4 `rptr_empty #(ADDR_W)`

Mirror of 5.3: ports `rclk, rrst_n, rd_en, wgray_sync → raddr, rgray, empty, almost_empty`.

- `rbin_next = rbin + (rd_en && !empty)`
- `rgray_next = bin2gray(rbin_next)`
- `empty_next = (rgray_next == wgray_sync)`
- `occupancy = gray2bin(wgray_sync) - rbin_next` (post-read occupancy)
- `almost_empty_next = (occupancy <= DEPTH/4)`
- Outputs: `raddr = rbin[ADDR_W-1:0]`; `rgray` is the registered gray read pointer.
- Registered on `rclk`.
- Reset values: `rbin = 0, rgray = 0, empty = 1, almost_empty = 1`.
  (A reset FIFO is empty; starting `empty = 1` avoids the one-cycle spurious
  `empty = 0` after reset. Worth one sentence in the report.)

## 6. Read data path: the async read contract (and why it matters)

### 6.1 The contract

- `raddr` is a flop in the read domain: it changes only at a `rd_clk` edge and
  only when `rd_en && !empty`.
- `rdata = mem[raddr]` is combinational: it always shows the word at the
  *current* read address, i.e. the oldest entry whenever `!empty`.
- The consumer samples `rdata` **at the `rd_clk` edge**, qualified by
  `rd_en && !empty` evaluated just before that edge.

```
              edge N
rd_clk    __/‾‾‾\__/‾‾‾\__
rd_en     _____/‾‾‾‾‾‾‾\___
empty     ‾‾‾‾‾‾‾‾‾\_______     (deasserts once a word is available)
raddr     ===== P =====| P+1
rdata     ===== D_P ===| D_P+1
                ^ sample D_P here: rd_en=1, empty=0, rdata valid
```

At edge N the data is already `D_P` before the edge, so the consumer's flop
captures it; only after the edge does `raddr` advance to `P+1`. In other words,
**the consumer's flop is the FIFO's output register** — that is why `fifo_mem`
needs no `rd_en`: a "read" is defined as "the read pointer advances".

`rdata` is *not* qualified by `empty`: when the FIFO is empty, `raddr` points at
stale data. Always qualify with `rd_en && !empty` at the edge.

### 6.2 Worked example: streaming 4 words back-to-back

FIFO holds `D0, D1, D2, D3`; the consumer asserts `rd_en` every cycle and samples
at the end-of-cycle edge.

**Async read (this design):**

| Cycle | empty | rd_en | rdata (combinational) | captured at edge |
|---|---|---|---|---|
| 1 | 0 | 1 | `D0` | `D0` |
| 2 | 0 | 1 | `D1` | `D1` |
| 3 | 0 | 1 | `D2` | `D2` |
| 4 | 0 | 1 | `D3` | `D3` |
| 5 | 1 | 1 | stale | — (blocked by empty) |

4 words in 4 cycles, first word available immediately.

**Registered read** (`always_ff @(posedge rclk) if (rd_en && !empty) rdata <= mem[raddr];`):

| Cycle | empty | rd_en | rdata (FIFO flop) | captured at edge | note |
|---|---|---|---|---|---|
| 1 | 0 | 1 | old | — | FIFO loads `D0` at edge 1 |
| 2 | 0 | 1 | `D0` | `D0` | FIFO loads `D1` at edge 2 |
| 3 | 0 | 1 | `D1` | `D1` | |
| 4 | 0 | 1 | `D2` | `D2` | FIFO loads `D3` at edge 4 |
| 5 | 1 | 1 | `D3` | `D3` **but needs dvalid** | `empty=1` while `rdata` is valid |

Two problems: the first word arrives one cycle late, and in cycle 5 `rdata = D3`
is valid while `empty = 1`, so the simple `rd_en && !empty` rule **drops it**.
A registered read therefore needs a delayed valid signal for the consumer:
`dvalid` = `rd_en && !empty` delayed one cycle, or equivalently `empty` delayed
by one cycle.

### 6.3 Last-word edge case

FIFO has exactly one entry `D_last` at address `P`:

```
rd_clk    __/‾‾‾\__/‾‾‾\__
rd_en     _____/‾‾‾‾‾‾‾\___
empty     ‾‾‾‾‾\___________     (goes high AT edge N — FIFO is now empty)
raddr     ==== P ===| P+1
rdata     ==== D_last =| stale
                ↑ still captures D_last: empty was 0 just before the edge
```

Async read is safe here: `empty` rising at edge N does not hurt because the data
was already presented before the edge. With a registered read, `D_last` only
reaches the consumer at edge N+1, when `empty` is already 1 — exactly the
contract shift described above.

### 6.4 Why the async read path is used here

- **Zero read latency**: the first word is available in the same cycle `empty`
  deasserts; a burst of N words takes N cycles instead of N+1.
- **`empty` and `rdata` stay aligned in the same cycle**, so no pipelined
  valid/delayed-empty bookkeeping is needed and the consumer rule stays simply
  `rd_en && !empty`.
- **The consumer's flop serves as the output register**, so the FIFO needs no
  extra output register and no pipelined `empty` — less logic, simpler timing.
- **Uniform edge contract**: both sides commit at the clock edge (writes commit
  `wdata` at the `wr_clk` edge; reads commit `rdata` at the `rd_clk` edge), and
  the registered flags reflect the next state.
- **Trade-off**: `rdata` is a combinational mux over `DEPTH` words. Fine for
  depth 16 (flops + read mux). A large FIFO would use an SRAM with a synchronous
  read port, and *then* it must add an output register plus a pipelined
  valid/empty — precisely the complexity the async path avoids at this size.

TB implication: sample `rdata`/`empty` at the `rd_clk` edge (drive and sample
synchronously), not with mid-cycle `#delay`s, or you will capture the post-edge
`raddr` value.

## 7. Gray-code helpers (shared `fifo_utils` package)

Declared once at the top of `async_fifo.sv`, before the modules; imported by
`wptr_full` and `rptr_empty` with `import fifo_utils::*;`.

```systemverilog
package fifo_utils;

    function automatic logic [31:0] bin2gray(input logic [31:0] bin);
        return bin ^ (bin >> 1);
    endfunction

    function automatic logic [31:0] gray2bin(input logic [31:0] gray);
        logic [31:0] bin;
        bin = gray;
        for (int i = 1; i < 32; i++)
            bin ^= (gray >> i);
        return bin;
    endfunction

endpackage
```

Arguments and returns are 32 bits: unsigned narrower values are zero-extended,
so the extra high-order XOR terms are 0 and the result is the exact `PTR_W`-bit
conversion for any `ADDR_W` up to 26.

## 8. Correctness rules (checklist while writing)

- Only gray pointers cross clock domains; binary pointers never do.
- Every CDC path goes through a 2FF synchronizer in the receiving domain.
- Flags are registered in their own domain → glitch-free and **Moore** style
  (report answer).
- Pointer increments are gated by `!full` / `!empty`.
- `almost_full` / `almost_empty` are conservative: the synchronized pointer is
  stale by 2 cycles, so flags may assert early — safe, document it.
- Sequential logic uses nonblocking (`<=`), combinational logic blocking (`=`),
  and only `always_ff` / `always_comb`.
- Memory has no reset; pointers/flags do.
- `DEPTH` must stay a power of 2 (gray code requirement).

## 9. TODO checklist

- [x] `fifo_utils` package (bin2gray/gray2bin)
- [x] `fifo_mem` module
- [x] `wptr_full` module
- [x] `rptr_empty` module
- [x] top-level behavioral 2FF synchronizers (both directions)
- [x] Top-level aliases, internal wires, explicit instantiations, output assigns
- [x] `cd sim && source ../env.sh && make lint` is clean
- [x] `make compile` elaborates and links
- [x] Testbench: clocks, resets, FSDB, stimulus, scoreboard, stresses
- [x] Synthesis: Fmax / constraints / area / power collected (section 11)

## 10. Build and verify

```bash
cd sim
source ../env.sh
make lint      # vlogan parse of ../rtl/*.sv
make compile   # VCS compile + elaborate with ../tb/*.sv
cd ../synth && make synth   # Design Compiler
```

## 11. Synthesis results (Design Compiler)

Tool `V-2023.12-SP5-1`, library `gscl45nm` (FreePDK45), script
`synth/compile_dc.tcl` (run via `make synth`).

Constraints applied:
- `create_clock` on both domains: 1.00 ns period (1000 MHz target)
- `set_clock_groups -asynchronous -group wr_clk -group rd_clk` — CDC paths are
  not timed (the lab's "false path / async clocks" requirement)
- per-domain I/O delays 0.1 ns vs the domain clock: write side (`wdata`,
  `wrst_n`, `wr_en` in; `full`, `almost_full` out) vs `wr_clk`; read side
  (`rrst_n`, `rd_en` in; `rdata`, `empty`, `almost_empty` out) vs `rd_clk`
- `set_driving_cell INVX1` on all inputs; `map_effort medium`
- Note: DC flattens the interface port, so top-level port names are
  `fifo_port.<signal>`.

Results at 1.00 ns period (both domains MET):

| Domain | Worst slack | Critical path | Fmax = 1/(T - slack) |
|---|---|---|---|
| write (`wr_clk`) | +0.11 ns | `u_wptr_full/full_reg` → `full_reg` (full compare) | ~1.12 GHz |
| read (`rd_clk`) | +0.02 ns | `wgray2_reg[3]` → `u_rptr_empty/almost_empty_reg` (gray2bin + subtract + compare) | ~1.02 GHz |

Area / power:
- Total cell area 3773.64 (combinational 2298.16, noncombinational 1475.48)
- 1224 cells (1008 combinational, 172 sequential), 26 ports, 529 buf/inv
- Total power 3.13 mW (internal 3.00 mW, switching 0.10 mW, leakage 22.3 uW)
- Interconnect area undefined (no wire load model); power without annotated
  switching activity

Observations:
- The read domain is the slower one: `almost_empty` needs `gray2bin` +
  subtraction + compare in a single cycle, while the write side only needs the
  gray full-compare.
- Synthesis exposed two RTL issues that simulation tolerated: missing
  `full_next`/`almost_full_next` declarations (implicit wires) and signed vs
  unsigned threshold comparisons (fixed with `int unsigned DEPTH`).
- Fmax is derived from a single 1 ns run (slack-based); a period sweep would
  refine it.
