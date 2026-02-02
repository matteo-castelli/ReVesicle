###############################################################################
# LOAD SYSTEM
###############################################################################

if {![info exists env(REVESICLE_STEP1A_BASENAME)]} {
    puts "ERROR: REVESICLE_STEP1A_BASENAME not set."
    puts "       This must be provided by ReVesicle.sh."
    exit 1
}

set basename $env(REVESICLE_STEP1A_BASENAME)

# STEP-1_A structure 
set js_file "../STEP-1_A/${basename}.js"

puts "==> Loading STEP-1_A system:"
puts "    JS   = $js_file"

mol new $js_file waitfor all
mol addfile STEP-2_A.dcd type dcd waitfor all

set sel [atomselect top "not resname TIP3 CLA SOD"]
$sel writejs STEP-2_A_stripped.js
animate write dcd STEP-2_A_stripped.dcd beg 0 end -1 skip 1 waitfor all sel $sel top

quit
