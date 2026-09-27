#!/bin/bash
# Source this file before running VCS/Verdi/Design Compiler:
#   source env.sh

source /mnt/vault0/jiajunh5/set_cad.sh

# FreePDK45 (osu_soc) root; compile_dc.tcl uses $PDK_DIR/osu_soc/lib/files
export PDK_DIR=/mnt/vault0/jiajunh5

# set_cad.sh sets VERDI_HOME but not PATH
export PATH=$VERDI_HOME/bin:$PATH
