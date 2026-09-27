# ADDV Lab #1 — FIFO Design (Part II: Even/Odd Alternating Circuit)

SystemVerilog design + verification + synthesis of an even/odd alternating circuit.

## Setup (csh)

```bash
source env.cshrc
which vcs verdi
```

## Layout

| Path | Contents |
|---|---|
| `rtl/` | Design RTL (`fifo_interface.sv`, `async_fifo.sv`, ...) |
| `rtl/design.md` | Even/odd alternating circuit design overview |
| `tb/testbench.md` | Testbench overview |
| `tb/` | Testbenches (`tb_alternating_circuit.sv`) with data |
| `sim/` | VCS/Verdi Makefile (reused from Lab #0) |
| `synth/` | Design Compiler Makefile + `compile_dc.tcl` |

## Simulation

```bash
cd sim
make compile              # compile RTL + TB
make sim                  # run ./simv
make sim ARGS="+test=1"   # run a specific scenario
make compile_verdi        # compile with Verdi KDB
make sim                  # produces novas.fsdb
make waves_verdi          # open Verdi with waves
make clean                # remove generated files
```

Note: `sim/` compiles both testbenches in `tb/`; the Makefile selects
`tb_alternating_circuit` via `TOP` (override with `make compile_verdi
TOP=tb_async_fifo`). Input data is loaded from `../tb/data` (override with
`+DATA_DIR=<path>` if running from elsewhere).

## Synthesis

```bash
cd synth
make synth                # dc_shell-t -f compile_dc.tcl
cat area.rep power.rep timing.rep
```
