#/**************************************************/
#/* Compile Script for Synopsys                    */
#/*                                                */
#/* dc_shell-t -f compile_dc.tcl                   */
#/*                                                */
#/* OSU FreePDK 45nm                               */
#/**************************************************/

#/* All SystemVerilog files (DC analyze takes one file per call) */
set my_verilog_files [list ../rtl/fifo_interface.sv ../rtl/async_fifo.sv]

#/* Top-level Module                               */
set my_toplevel   async_fifo

#/* RTL defaults: DATA_WIDTH=8, DEPTH=16 (ADDR_W=4) */

#/* Interface port prefix after elaboration        */
#/* (DC flattens the interface port as fifo_port.*) */
set my_if fifo_port

#/* Write/read clock ports                         */
set my_write_clock_pin $my_if.wr_clk
set my_read_clock_pin  $my_if.rd_clk

#/* Target clock periods in ns (overridable via env)  */
#/*   WR_PERIOD_NS / RD_PERIOD_NS                     */
set my_wr_period_ns 1.0
set my_rd_period_ns 1.0
if { [info exists env(WR_PERIOD_NS)] } { set my_wr_period_ns $env(WR_PERIOD_NS) }
if { [info exists env(RD_PERIOD_NS)] } { set my_rd_period_ns $env(RD_PERIOD_NS) }

#/* Map effort (overridable: MAP_EFFORT=low|medium|high) */
set my_map_effort medium
if { [info exists env(MAP_EFFORT)] } { set my_map_effort $env(MAP_EFFORT) }

#/* Report filename suffix (overridable: RUN_TAG)     */
#/* e.g. RUN_TAG=p0.95 -> timing_wr_p0.95.rep         */
set my_tag ""
if { [info exists env(RUN_TAG)] && $env(RUN_TAG) ne "" } { set my_tag "_$env(RUN_TAG)" }

#/* Delay of input signals (Clock-to-Q, Package etc.)  */
set my_input_delay_ns 0.1

#/* Reserved time for output signals (Holdtime etc.)   */
set my_output_delay_ns 0.1


#/**************************************************/
#/* No modifications needed below                  */
#/**************************************************/
set OSU_FREEPDK [format "%s%s"  [getenv "PDK_DIR"] "/osu_soc/lib/files"]
set search_path [concat  $search_path $OSU_FREEPDK]
set alib_library_analysis_path $OSU_FREEPDK

set link_library [set target_library [concat  [list gscl45nm.db] [list dw_foundation.sldb]]]
set target_library "gscl45nm.db"
define_design_lib WORK -path ./WORK
set verilogout_show_unconnected_pins "true"

foreach f $my_verilog_files { analyze -f sverilog $f }

elaborate $my_toplevel

current_design $my_toplevel

link
uniquify

create_clock -period $my_wr_period_ns -name wr_clk [get_ports [list $my_write_clock_pin]]
create_clock -period $my_rd_period_ns -name rd_clk [get_ports [list $my_read_clock_pin]]
set_clock_groups -asynchronous -group [get_clocks wr_clk] \
                                -group [get_clocks rd_clk]

#/* per-domain I/O constraints */
set wr_inputs  [get_ports [list $my_if.wdata* $my_if.wrst_n $my_if.wr_en]]
set rd_inputs  [get_ports [list $my_if.rrst_n $my_if.rd_en]]
set wr_outputs [get_ports [list $my_if.full $my_if.almost_full]]
set rd_outputs [get_ports [list $my_if.rdata* $my_if.empty $my_if.almost_empty]]

set_driving_cell  -lib_cell INVX1  [all_inputs]
set_input_delay  $my_input_delay_ns  -clock wr_clk $wr_inputs
set_input_delay  $my_input_delay_ns  -clock rd_clk $rd_inputs
set_output_delay $my_output_delay_ns -clock wr_clk $wr_outputs
set_output_delay $my_output_delay_ns -clock rd_clk $rd_outputs

compile -ungroup_all -map_effort $my_map_effort

compile -incremental_mapping -map_effort $my_map_effort

check_design
report_constraint -all_violators

#set filename [format "%s%s"  $my_toplevel ".vh"]
#write -f verilog -output $filename

#set filename [format "%s%s"  $my_toplevel ".sdc"]
#write_sdc $filename

#set filename [format "%s%s"  $my_toplevel ".db"]
#write -f db -hier -output $filename -xg_force_db

redirect timing${my_tag}.rep    { report_timing -max_paths 3 }
redirect timing_wr${my_tag}.rep { report_timing -group wr_clk -max_paths 1 }
redirect timing_rd${my_tag}.rep { report_timing -group rd_clk -max_paths 1 }
redirect cell${my_tag}.rep      { report_cell }
redirect power${my_tag}.rep     { report_power }
redirect area${my_tag}.rep      { report_area }

quit
