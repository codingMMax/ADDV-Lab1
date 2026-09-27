# ADDV Lab #1 — FIFO Design (Part I: Asynchronous FIFO)

SystemVerilog design + verification + synthesis of a parameterized asynchronous FIFO.
Part II (even/odd alternating circuit) lives in `../part2/`.

## Setup

```bash
# private server (bash)
source env.sh          # set_cad.sh + PDK_DIR=/mnt/vault0/jiajunh5
which vcs verdi dc_shell-t

# Apporto (tcsh)
tcsh
source env.cshrc       # VCS/Verdi/DC paths + PDK_DIR for Apporto
```

Tool versions on this machine: VCS/VERDI `U-2023.03-SP2`, Design Compiler `V-2023.12-SP5-1`,
library `gscl45nm` (FreePDK45 at `$PDK_DIR/osu_soc/lib/files`).

## Layout

| Path | Contents |
|---|---|
| `rtl/` | Design RTL (`fifo_interface.sv`, `async_fifo.sv`, ...) |
| `rtl/design.md` | Detailed async FIFO design spec (blocks, signals, resets) |
| `tb/testbench.md` | Testbench overview: transfer contract, scoreboard rules, bring-up flow |
| `tb/` | Testbenches (`tb_async_fifo.sv`) |
| `sim/` | VCS/Verdi Makefile (reused from Lab #0) |
| `synth/` | Design Compiler Makefile + `compile_dc.tcl` |
| `docs/figures/` | Microarchitecture diagram + annotated waveform screenshots |

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

## Synthesis

```bash
cd synth
make synth                # dc_shell-t -f compile_dc.tcl
cat area.rep power.rep timing.rep
```

Note: `compile_dc.tcl` applies dual-clock constraints (async clock groups,
per-domain I/O delays) and reports timing/area/power — results summarized in
`rtl/design.md` §11. Verified: DC `V-2023.12-SP5-1` elaborates SystemVerilog
`interface` ports with `modport` (no synthesis wrapper needed). Keep the
interface simple (signals + modports only; no clocking blocks).
