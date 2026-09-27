all: synth clean_synth

# This runs synthesis with Design Compiler
synth:
	dc_shell-t  -f  compile_dc.tcl |& tee synth.log


# Period sweep to find each domain's max frequency (slack ~ 0).
# Same period for both domains: within-domain paths are disjoint because the
# clocks are grouped as asynchronous. Tagged reports/logs per run.
sweep:
	@for p in 1.00 0.97 0.95 0.93 0.91 0.89 0.87 0.85 0.80; do \
	  echo "===== period $$p ns (wr and rd) ====="; \
	  WR_PERIOD_NS=$$p RD_PERIOD_NS=$$p RUN_TAG=p$$p dc_shell-t -f compile_dc.tcl > sweep_p$$p.log 2>&1; \
	  grep -H 'slack (' timing_wr_p$$p.rep timing_rd_p$$p.rep 2>/dev/null || echo "  (no report - see sweep_p$$p.log)"; \
	done

# High-effort run at a chosen period: make sweep_high P=0.89
sweep_high:
	WR_PERIOD_NS=$(P) RD_PERIOD_NS=$(P) RUN_TAG=high_p$(P) MAP_EFFORT=high dc_shell-t -f compile_dc.tcl > sweep_high_p$(P).log 2>&1
	grep -H 'slack (' timing_wr_high_p$(P).rep timing_rd_high_p$(P).rep 2>/dev/null || true

clean_sweep:
	\rm -f sweep_p*.log sweep_high*.log
	\rm -f timing_wr_p*.rep timing_rd_p*.rep timing_p*.rep cell_p*.rep power_p*.rep area_p*.rep
	\rm -f timing_wr_high*.rep timing_rd_high*.rep timing_high*.rep cell_high*.rep power_high*.rep area_high*.rep


clean_synth:
	\rm -rf *.syn *.pvl *.mr *.svf command.log  WORK

clean:
	\rm -rf csrc DVEFiles simv.daidir simv ucli.key vcdplus.vpd *.syn *.pvl *.mr *.svf command.log *.txt cksum_dir *.log *.rep WORK/
