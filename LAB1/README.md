# ADDV Lab #1 — FIFO Design (Part I + Part II)

Working repository for both parts of Lab #1. Each part is self-contained so it
can be zipped/run independently; Part 2 reuses the Part 1 FIFO.

## Layout

| Path | Contents |
|---|---|
| `part1/` | Part I: asynchronous FIFO — RTL, testbench, sim/synth scripts |
| `part2/` | Part II: even/odd alternating circuit built on the FIFO — RTL, testbench, data files, sim/synth scripts |

## Part I — Asynchronous FIFO

- RTL: `part1/rtl/fifo_interface.sv`, `part1/rtl/async_fifo.sv`
- Design spec: `part1/rtl/design.md` (includes synthesis results, §11)
- Testbench: `part1/tb/tb_async_fifo.sv`; overview `part1/tb/testbench.md`
- Setup: `source part1/env.sh` (bash, this server) or `source part1/env.cshrc` (tcsh, Apporto)
- Run: `cd part1/sim && make compile_verdi && make sim` (waves: `make waves_verdi`)
- Synthesis: `cd part1/synth && make synth`
- Status: sim `writes=420 reads=420 errors=0`; Fmax ~1.12 GHz write / ~1.02 GHz
  read; area 3773.64; total power 3.13 mW (gscl45nm)

## Part II — Even/Odd Alternating Circuit

- RTL: `part2/rtl/alternating_circuit.sv`, `store_input.sv`,
  `produce_sorted_output.sv`, `alternative_circuit_interface.sv`, plus the
  reused `async_fifo.sv` / `fifo_interface.sv`
- Design overview: `part2/rtl/design.md`
- Testbench: `part2/tb/tb_alternating_circuit.sv` + `part2/tb/data/*.dat`;
  overview `part2/tb/testbench.md`
- Setup (tcsh/Apporto style): `source part2/env.cshrc`
- Run: `cd part2/sim && make compile_verdi && make sim`
  (`part2/sim` selects `tb_alternating_circuit` via `TOP`; override with
  `make compile_verdi TOP=tb_async_fifo` to run the reused FIFO TB)
- Known TODOs: `part2/synth/compile_dc.tcl` still points at the Part I files/top
  (`async_fifo`) and must be pointed at `alternating_circuit` and the Part II
  RTL; the Part II testbench scenarios/`+test` dispatch still need wiring.

## Notes

- Tool-generated artifacts (`csrc/`, `simv*`, `novas.fsdb`, `WORK/`, `*.rep`,
  logs) are gitignored and excluded from submission zips. Run `make clean` in
  `part1/sim`/`part2/sim` and `make clean_synth` in the synth dirs to remove
  them from disk.
- `part1/env.sh` targets this server (`/mnt/vault0/...`); `part2/env.cshrc`
  targets the Apporto environment. Adjust paths when moving machines.
