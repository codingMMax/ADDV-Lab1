
all: sim clean

# This compiles with VCS and runs simulation
compile_and_sim:
	${VCS_HOME}/bin/vcs -R -full64 -sverilog ../rtl/*.sv ../tb/*.sv -debug_access+all |& tee compile_and_sim.log

# Analyze RTL only (no testbench yet); good for step-by-step development
lint:
	${VCS_HOME}/bin/vlogan -full64 -sverilog ../rtl/*.sv |& tee lint.log

# This compiles with VCS
compile:
	${VCS_HOME}/bin/vcs -full64 -sverilog ../rtl/*.sv ../tb/*.sv -debug_access+all |& tee compile.log

# This compiles with VCS and also generates the database for Verdi
compile_verdi:
	${VCS_HOME}/bin/vcs -full64 -sverilog ../rtl/*.sv ../tb/*.sv -debug_access+all -kdb -lca |& tee compile_verdi.log

# This runs simulation; pass plusargs via ARGS, e.g. make sim ARGS="+test=1"
sim:
	./simv $(ARGS)

# This launches Verdi
waves_verdi:
	$(VERDI_HOME)/bin/verdi -dbdir ./simv.daidir -ssf novas.fsdb -nologo

clean:
	\rm -rf *.log *.h  csrc DVEFiles AN.DB simv.daidir simv ucli.key vcdplus.vpd *.syn *.pvl *.mr *.svf command.log *.txt novas.conf  novas.rc  verdi_config_file  verdiLog novas.fsdb novas.log novas_dump.log
