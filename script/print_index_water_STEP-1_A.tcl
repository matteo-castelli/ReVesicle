# ------------------------------------------------------------------
# Read STEP-1_A system basename from environment
# ------------------------------------------------------------------
if {![info exists env(REVESICLE_STEP1A_BASENAME)]} {
    puts "ERROR: REVESICLE_STEP1A_BASENAME not set."
    puts "       This must be provided by ReVesicle.sh."
    exit 1
}

set basename $env(REVESICLE_STEP1A_BASENAME)

set js_file   "${basename}.js"
#set coor_file "${basename}.coor"

puts "==> Loading STEP-1_A system:"
puts "    JS   = $js_file"
#puts "    COOR = $coor_file"

mol new $js_file waitfor all
#mol addfile $coor_file waitfor all

set index_file [open "index_water_A.dat" w]

set wt_ions [atomselect top "water or name CLA SOD"]
set wt_ions_seg [$wt_ions get index]; llength $wt_ions_seg

foreach i $wt_ions_seg {
    puts $index_file "$i"
    if {$i%100000 == 0} {puts $i}
}

close $index_file
quit
