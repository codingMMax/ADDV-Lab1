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

## Part I RTL parameters

- `DATA_WIDTH = 8`
- `DEPTH = 16` (`ADDR_W = 4`) — depth must be a power of 2 for gray-code pointers
- Separate `wr_clk` / `rd_clk`, gray-code pointers with 2FF synchronizers
- `full` / `empty` plus `almost_full` at 75% and `almost_empty` at 25% occupancy
- SystemVerilog style: `always_ff`/`always_comb`, `logic`, `.*` instantiation, interface + modports

## Part I verification checklist (from the lab page)

1. FIFO empty and then filled; FIFO full and then emptied
2. Correct assertion of `almost_full` and `almost_empty` flags
3. Simultaneous read and write with different clock frequencies
4. Self-checking scoreboard (data integrity), plus FSDB dumps for annotated waveform screenshots

## Deliverables checklist (Part I)

- [ ] Hand-drawn microarchitecture diagram (memory, synchronizer FFs, flag logic, pointer logic)
- [ ] Annotated waveform snapshots for the 3 verification requirements
- [ ] FULL/EMPTY Mealy-or-Moore answer (1-2 sentences)
- [ ] Synthesis results: max frequency per clock domain, constraints (async clocks/false paths), area, power
- [ ] Summary of AI-tool interaction; one bug + debugging story
- [ ] Code + Makefile + README (no tool-generated files), report PDF + zip named with both partners

## Git

Local repo initialized here; partner remote to be added later. Tool-generated artifacts
are ignored via `.gitignore` — keep the submission zip clean.
