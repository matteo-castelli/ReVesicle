# Tcl Script

mol new STEP-1_B_empty_holes.js
set index_file [open "index_water_B.dat" w]

set wt_ions [atomselect top "water or name CLA SOD"]
set wt_ions_seg [$wt_ions get index]; llength $wt_ions_seg

foreach i $wt_ions_seg {
    puts $index_file "$i"
    if {$i%100000 == 0} {puts $i}
}

close $index_file
quit
