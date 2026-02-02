# Tcl Script

mol new STEP-4_empty_holes.js 
set index_file [open "index_lipid_heads.dat" w]

set wt_ions [atomselect top "lipid and name P O3"]
set wt_ions_seg [$wt_ions get index]; llength $wt_ions_seg

foreach i $wt_ions_seg {
    puts $index_file "$i"
    if {$i%100000 == 0} {puts $i}
}

close $index_file
quit
