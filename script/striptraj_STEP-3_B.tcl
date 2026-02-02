###############################################################################
# LOAD SYSTEM
###############################################################################

mol new ../STEP-1_B/STEP-1_B_empty_holes.js waitfor all
mol addfile STEP-3_B.dcd type dcd waitfor all

set sel [atomselect top "not resname TIP3 CLA SOD"]
$sel writejs STEP-3_B_stripped.js
animate write dcd STEP-3_B_stripped.dcd beg 0 end -1 skip 1 waitfor all sel $sel top

quit
