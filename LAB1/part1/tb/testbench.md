# Async FIFO Testbench — Overview & Guidelines

Companion to `rtl/design.md`. Describes the TB architecture, the transfer
contract, and the incremental bring-up flow. Fill in the waveform-probing
details in section 8 as the tests evolve.

## 1. Scope

- DUT: `async_fifo`, write domain 100 MHz (10 ns), read domain 50 MHz (20 ns)
- Plain Verilog-style TB (no classes/UVM); self-checking via a reference model
- Evidence for the report: annotated waveform snapshots (fill, drain,
  simultaneous R/W with different clocks) + PASS/FAIL summary per scenario

## 2. Architecture

| Piece | Role |
|---|---|
| `fifo_bus` | `fifo_interface` instance; DUT connects through `.fifo_side` |
| `wr_clk` / `rd_clk` | independent free-running clocks (10 ns / 20 ns) |
| resets | asserted at t=0; `wrst_n`/`rrst_n` deasserted on their own clock edges |
| FSDB | `$fsdbDumpfile("novas.fsdb")` + `$fsdbDumpvars(0, tb_async_fifo, "+mda")` |
| watchdog | 500 us safety timeout (report() should finish long before) |
| scoreboard | expected queue + counters (section 4) |
| tasks | stimulus drivers: `write_once`, `read_aligned` |
| dispatch | `$value$plusargs("test=%0d")` -> test1..test4 (TODO) |

## 3. Transfer contract (how to sample)

- A **write transfer** happens iff `wr_en && !full` at a `wr_clk` rising edge;
  the word is `wdata`.
- A **read transfer** happens iff `rd_en && !empty` at an `rd_clk` rising edge;
  `rdata` *just before* the edge is the word read (async-read contract).
- Sample in the active region at the edge: you get **pre-edge** values, exactly
  what the DUT used to decide the transfer.
- Drive stimulus with nonblocking (`<=`); do model bookkeeping with blocking (`=`).
- One writer per variable (write monitor owns `wr_ptr`/`num_writes`,
  read monitor owns `rd_ptr`/`num_reads`).
- Use `===` / `!==` for all DUT-vs-model comparisons (never `==` / `!=`).
- Time advances only at `@` / `#`; statements between events run in zero time.

## 4. Scoreboard behavior

- **In**: accepted write appends `wdata` at `wr_ptr`.
- **Out**: accepted read compares `rdata` against `expected_queue[rd_ptr]`, then
  retires (advances `rd_ptr`).
- Live range `[rd_ptr, wr_ptr)`; each word goes: written -> live -> compared ->
  retired. Occupancy = `wr_ptr - rd_ptr`.
- **Correct** = match + invariants hold + clean drain at end of test.
- **Wrong** = mismatch, underflow (read while empty), overflow (write when
  occupancy would exceed DEPTH), count mismatch, flag errors.

## 5. Verification rules

| # | Rule | Status |
|---|---|---|
| R1 | read data/order matches queue head (`rdata === expected_queue[rd_ptr]`) | done |
| R2 | no read transfer when the model is empty (`rd_ptr >= wr_ptr`) | done |
| R3 | occupancy never exceeds DEPTH (no overflow) | done |
| R4 | `wr_ptr < TEST_LENGTH` array bound | done |
| R5 | reset state: `empty=1, almost_empty=1, full=0, almost_full=0` | TODO |
| R6 | exact flags at quiescence (settle S=4 edges of both clocks) | TODO |
| R7 | exact threshold timing in single-domain phases (12/16/4/0) | TODO |
| R8 | streaming flag liveness (assert within S cycles of condition holding) | TODO |
| R9 | end accounting: `num_reads == num_writes`, queue drained, `empty=1` | done (end-of-test checks) |

Notes:
- Almost flags are computed in their own domain from a 2FF-synchronized remote
  pointer, so during streaming they may assert **early**, never late. Exact
  comparisons are only valid at quiescent points (or in single-domain phases).
- Settling/latency bound S = 4 cycles of the relevant clock (sync depth 2 + margin).

## 6. Scenarios

| Test | Content | Exercises | Status |
|---|---|---|---|
| 1 | empty->fill->full (no reads), then drain->empty (no writes) | exact flags R5/R6/R7 | done (sequential smoke) |
| 2 | simultaneous R/W, writer faster (200 words) | full/backpressure, R1-R4 | done ("FILL STRESS") |
| 3 | simultaneous R/W, bursty writer (8 writes per 100 wr cycles) | almost_empty/empty flapping | done ("DRAIN STRESS") |
| 4 | 1000 words, random data + random gaps both sides | long CDC runs, R1-R4 | planned |

Current run (no plusargs yet) executes sequentially: smoke -> FILL STRESS -> DRAIN
STRESS -> quiescent end checks, total 420 writes / 420 reads, ending drained.
Phase markers `=== FILL STRESS START/END ===` and `=== DRAIN STRESS START/END ===`
bracket the windows in the FSDB for annotated waveform captures.

Rate math (why the tests look like this): writer offers up to 100 M words/s,
reader drains up to 50 M words/s -> the FIFO fills in ~320 ns and then sits
essentially full; test 3's slow writer keeps it near empty instead.

## 7. How to run

```bash
cd sim
source ../env.sh               # VCS_HOME / VERDI_HOME / PATH / PDK_DIR
make compile_verdi             # -kdb -lca, required for FSDB + Verdi
make sim ARGS="+test=1"        # scenario run (dispatch TODO)
make waves_verdi               # verdi -dbdir simv.daidir -ssf novas.fsdb
```

The current smoke sequence (A0,B0,C0 read A; D0, read B, read C) runs
unconditionally until the `+test=N` dispatch is added.

## 8. Waveform probing (fill in)

- Suggested signals: `wr_clk, rd_clk, wr_en, wdata, full, almost_full, rd_en,
  rdata, empty, almost_empty` plus DUT internals `wgray, rgray, waddr, raddr`.
- Snapshots to capture:
  1. fill phase: `almost_full` at occupancy 12, `full` at 16
  2. drain phase: `almost_empty` at 4, `empty` at 0
  3. simultaneous R/W phase: different clock frequencies, write/read handshakes
- (Add exact signal lists / Verdi groups here.)

## 9. Bring-up flow (learn by running)

1. Clocks/reset only -> check flags after reset (`empty=1`, `full=0`).
2. Event prints only -> run the smoke sequence, confirm every transfer prints.
3. Scoreboard R1/R2 -> deliberately break the comparison once to see it fail.
4. Add R3/R4 (done), flag checks R5-R8 (inline exact checks in single-domain
   phases done; quiescent task + streaming liveness still TODO).
5. Scenario tasks + `+test=N` dispatch, then `report()` PASS/FAIL summary.

Pitfalls learned during bring-up:
- Declaration initializers are **one-time** assignments: alias interface signals
  with continuous `assign`, not `logic x = fifo_port.x;` (otherwise the DUT
  clock stays frozen at its time-0 value).
- Async resets must see a real negedge after time 0: drive resets deasserted
  first, then assert low on a clock edge before releasing.
- Let one or two extra clock edges pass after the final transfer before
  printing the summary / calling `$finish`, or the last monitor event may race
  with `$finish` in the same timestep.

## 10. TODO

- [ ] R5-R8 checks: assert reset state; quiescent `check_flags` task; streaming liveness
- [ ] scenario tasks `test1..test4` and `$value$plusargs` dispatch
- [ ] annotated waveform snapshots for the report (use the `=== ... ===` markers)
- [ ] keep `$display` logs clean enough to read a full run (verbosity gate)
