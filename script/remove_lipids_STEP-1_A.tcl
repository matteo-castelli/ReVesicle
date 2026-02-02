# Tcl script

# ------------------------------------------------------------------
# Read required offsets for lipid removal from environment
# These are passed by ReVesicle.sh when -lipids on:
#   REVESICLE_D3, REVESICLE_D4
# ------------------------------------------------------------------
if {![info exists env(REVESICLE_D3)] || ![info exists env(REVESICLE_D4)]} {
    puts "ERROR: REVESICLE_D3 and/or REVESICLE_D4 not set."
    puts "       Run ReVesicle.sh with: -lipids on -d3 N -d4 N"
    exit 1
}
set d3 $env(REVESICLE_D3)
set d4 $env(REVESICLE_D4)

mol new STEP-1_A_empty_holes.js waitfor all
mol addfile STEP-1_A_empty_holes.coor waitfor all

set outfile [open "output_lipids_holes.txt" w]

# Select only lipids
set membrane [atomselect top "lipid" frame last]

# Calculate membrane C.O.M.
set membrane_com [measure center $membrane]
set membrane_com_x [lindex $membrane_com 0]
set membrane_com_y [lindex $membrane_com 1]
set membrane_com_z [lindex $membrane_com 2]

# Calculate min max
set min_max [measure minmax $membrane]
set min [lindex $min_max 0]
set max [lindex $min_max 1]

# Calculate diameter and radius of the membrane (still have x,y,z)
set diam [vecsub $max $min]

set diam_x [lindex $diam 0]
set diam_y [lindex $diam 1]
set diam_z [lindex $diam 2]

set diam_avg [expr {($diam_x + $diam_y + $diam_z)/3}]

# Calculate radius --> approximation to a perfect sphere (averagin over x,y,z radius)
set radius [expr {($diam_avg/2)}]

# Select lipids in holes
set lipids [atomselect top "((name P) or (name O3 and resname CHL1)) and ((x-$membrane_com_x)*(x-$membrane_com_x) + (y-$membrane_com_y)*(y-$membrane_com_y) + (z-$membrane_com_z)*(z-$membrane_com_z)) < (($radius-$d3)*($radius-$d3)) and ((x-$membrane_com_x)*(x-$membrane_com_x) + (y-$membrane_com_y)*(y-$membrane_com_y) + (z-$membrane_com_z)*(z-$membrane_com_z)) > (($radius-$d4)*($radius-$d4))" frame last]
set lipids_residue [lsort -unique -real [$lipids get residue]]
set lipids_residue_l [llength [lsort -unique -real [$lipids get residue]]]

puts $outfile "\nRemoving $lipids_residue_l lipids, residues: $lipids_residue"

# Select glycolipids in holes
set glycolipids [atomselect top "((name C1S and resname C160)) and ((x-$membrane_com_x)*(x-$membrane_com_x) + (y-$membrane_com_y)*(y-$membrane_com_y) + (z-$membrane_com_z)*(z-$membrane_com_z)) < (($radius-$d3)*($radius-$d3)) and ((x-$membrane_com_x)*(x-$membrane_com_x) + (y-$membrane_com_y)*(y-$membrane_com_y) + (z-$membrane_com_z)*(z-$membrane_com_z)) > (($radius-$d4)*($radius-$d4))" frame last]
set glycolipids_residue [lsort -unique -real [$glycolipids get residue]]
set glicolipids_residue_l [llength [lsort -unique -real [$glycolipids get residue]]]

set glycolipids_list {}

foreach g $glycolipids_residue {
    set sel [atomselect top "residue $g"]
    set sel_segname [lsort -unique [$sel get segname]]
    $sel delete

    if {[string match "GA*" $sel_segname]} {
        lappend glycolipids_list $g [expr {$g + 1}] [expr {$g + 2}]
    } elseif {[string match "GB*" $sel_segname]} {
        lappend glycolipids_list $g [expr {$g + 1}]
    } elseif {[string match "GC*" $sel_segname]} {
        lappend glycolipids_list $g [expr {$g + 1}] [expr {$g + 2}] [expr {$g + 3}]
    }
}

puts $outfile "\nRemoving [llength $glycolipids_residue] glycolipids, residues: $glycolipids_list"

foreach gr $glycolipids_list {
    set sel [atomselect top "residue $gr"]
    puts $outfile "Removing: [lsort -unique [$sel get {residue resname segname}]]"
}

puts $outfile "\nRemoving these lipids/glycolipids residues: $lipids_residue $glycolipids_list"
close $outfile

set removed_lipids [atomselect top "residue $lipids_residue $glycolipids_list" frame last]
$removed_lipids writejs removed_lipids_STEP-1_A.js
$removed_lipids writenamdbin removed_lipids_STEP-1_A.coor

set remove_lipids [atomselect top "not residue $lipids_residue $glycolipids_list" frame last]
$remove_lipids writejs STEP-1_A_empty_holes_lipids.js
$remove_lipids writenamdbin STEP-1_A_empty_holes_lipids.coor

quit

