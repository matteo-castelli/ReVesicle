###############################################################################
# LOAD SYSTEM
###############################################################################

mol new ../STEP-4/STEP-4_empty_holes.js waitfor all
mol addfile STEP-5.dcd type dcd waitfor all

set sel [atomselect top "not resname TIP3 CLA SOD"]
$sel writejs STEP-5_stripped.js
animate write dcd STEP-5_stripped.dcd beg 0 end -1 skip 1 waitfor all sel $sel top

quit
