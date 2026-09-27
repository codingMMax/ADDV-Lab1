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

#/* Target frequency; Fmax computed from slack     */
set my_clk_freq_MHz 1000

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

set my_period [expr 1000 / $my_clk_freq_MHz]

create_clock -period $my_period -name wr_clk [get_ports [list $my_write_clock_pin]]
create_clock -period $my_period -name rd_clk [get_ports [list $my_read_clock_pin]]
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

compile -ungroup_all -map_effort medium

compile -incremental_mapping -map_effort medium

check_design
report_constraint -all_violators

#set filename [format "%s%s"  $my_toplevel ".vh"]
#write -f verilog -output $filename

#set filename [format "%s%s"  $my_toplevel ".sdc"]
#write_sdc $filename

#set filename [format "%s%s"  $my_toplevel ".db"]
#write -f db -hier -output $filename -xg_force_db

redirect timing.rep    { report_timing -max_paths 3 }
redirect timing_wr.rep { report_timing -group wr_clk -max_paths 1 }
redirect timing_rd.rep { report_timing -group rd_clk -max_paths 1 }
redirect cell.rep      { report_cell }
redirect power.rep     { report_power }
redirect area.rep      { report_area }

quit
