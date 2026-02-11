###############################################################################
# STEP-1_A: REMOVE LIPIDS / GLYCOLIPIDS FROM MEMBRANE INTERIOR
#
# Purpose:
#   Identify phospholipids and glycolipids whose headgroups are located
#   within the membrane interior (between two concentric spherical surfaces)
#   and remove them from the structure generated after water removal.
#
# Inputs provided by ReVesicle.sh:
#   REVESICLE_D3 -> inner lipid offset (Å)
#   REVESICLE_D4 -> outer lipid offset (Å)
#
# Example CLI:
#   ./ReVesicle.sh -lipids on -d3 20 -d4 40
#
# Geometry:
#   Lipid-removal shell defined as:
#       (radius - d4) < r < (radius - d3)
#
# Notes:
#   - Membrane radius is approximated as the average of x/y/z extents.
#   - Glycolipid removal is fragment-based (entire bonded fragment removed).
#   - No dependence on segname.
###############################################################################

###############################################################################
# READ REQUIRED OFFSETS FROM ReVesicle.sh
###############################################################################

if {![info exists env(REVESICLE_D3)] || ![info exists env(REVESICLE_D4)]} {
    puts "ERROR: REVESICLE_D3 and/or REVESICLE_D4 not set."
    puts "Run ReVesicle.sh with: -lipids on -d3 <value> -d4 <value>"
    quit
}

set d3 $env(REVESICLE_D3)
set d4 $env(REVESICLE_D4)

puts "==> STEP-1_A Lipid-removal offsets:"
puts "    d3 (inner) = $d3 Å"
puts "    d4 (outer) = $d4 Å"

###############################################################################
# DEFINE VMD MACROS: if any residue is missing, add it to the lists
###############################################################################

atomselect macro glycan {resname NAG BGLN BGLCNA FUC AFUC BFUC AGAL BGAL MAN AMAN BMA BMAN BCNA ANE5 ANE5AC BNE5AC AGAN AGALNA AGALNAC BGLC BGAN AGAN}

atomselect macro lipid {resname DLPE DMPC DPPC GPC LPPC PALM PC PGCL POPC POPE POPS POPI POPI2A POPI24 PI2A PI24 PI25 CHL1 PSM LSM NSM CER1 TLCL TLCL2 BMGP SOPE SOPS SAPC SAPE SAPS SLPE SLPS PLPI DHPC C160 C240 PLA2 PPEE}

###############################################################################
# LOAD STRUCTURE FROM PREVIOUS WATER CLEANUP
###############################################################################
# Input:
#   STEP-1_A_empty_holes.{js,coor}
###############################################################################

mol new STEP-1_A_empty_holes.js waitfor all
mol addfile STEP-1_A_empty_holes.coor waitfor all

###############################################################################
# CLEANUP OLD OUTPUT FILE
###############################################################################

if { [file exists ./output_lipids_holes.txt] == 1} {
    puts "Output file present. Removing old version..."
    exec rm ./output_lipids_holes.txt
}

set outfile [open "output_lipids_holes.txt" w]

###############################################################################
# COMPUTE MEMBRANE CENTER OF MASS AND APPROXIMATE RADIUS
###############################################################################

set membrane [atomselect top "lipid" frame last]

set membrane_com   [measure center $membrane]
set membrane_com_x [lindex $membrane_com 0]
set membrane_com_y [lindex $membrane_com 1]
set membrane_com_z [lindex $membrane_com 2]

set min_max [measure minmax $membrane]
set min     [lindex $min_max 0]
set max     [lindex $min_max 1]

set diam     [vecsub $max $min]
set diam_x   [lindex $diam 0]
set diam_y   [lindex $diam 1]
set diam_z   [lindex $diam 2]
set diam_avg [expr {($diam_x + $diam_y + $diam_z)/3.0}]
set radius   [expr {$diam_avg/2.0}]

puts "==> Geometry:"
puts "    membrane COM   = $membrane_com"
puts "    diam (x y z)   = $diam_x $diam_y $diam_z"
puts "    diam_avg       = $diam_avg"
puts "    radius         = $radius"

###############################################################################
# DEFINE SPHERICAL SHELL FOR LIPID REMOVAL
###############################################################################

set r_inner [expr {($radius-$d3)*($radius-$d3)}]
set r_outer [expr {($radius-$d4)*($radius-$d4)}]

set shell_expr "((x-$membrane_com_x)*(x-$membrane_com_x) + \
                 (y-$membrane_com_y)*(y-$membrane_com_y) + \
                 (z-$membrane_com_z)*(z-$membrane_com_z))"

###############################################################################
# SELECT PHOSPHOLIPID and CHOLESEROL HEADGROUPS IN SHELL
###############################################################################
# Detection criteria:
#   - Phosphate atom (name P)
#   - Cholesterol oxygen (O3 in CHL1)

set lipid_sel "((name P) or (name O3 and resname CHL1)) and \
               ($shell_expr < $r_inner) and \
               ($shell_expr > $r_outer)"

set lipids [atomselect top $lipid_sel frame last]

set lipids_residue   [lsort -unique -integer [$lipids get residue]]
set lipids_residue_l [llength $lipids_residue]

puts $outfile "\nRemoving $lipids_residue_l phospholipids:"
puts $outfile "$lipids_residue"

###############################################################################
# SELECT GLYCOLIPID HEADGROUPS IN SHELL
###############################################################################
# Glycolipids detected via head atom (C1S in C160/C240).
# Entire bonded fragment is removed if detected.

set glycolipid_sel "((name C1S and resname C160 C240)) and \
                    ($shell_expr < $r_inner) and \
                    ($shell_expr > $r_outer)"

set glycolipids [atomselect top $glycolipid_sel frame last]
set glycolipids_residue [lsort -unique -integer [$glycolipids get residue]]

set glycolipids_list {}

foreach g $glycolipids_residue {

    # Identify glycolipid fragment ID (force scalar!)
    set sel_head [atomselect top "residue $g"]
    set frag_id  [lindex [lsort -unique [$sel_head get fragment]] 0]
    $sel_head delete

    # Select full fragment (entire glycolipid)
    set sel_frag [atomselect top "fragment $frag_id"]

    # Get all residues belonging to this fragment
    set frag_res [lsort -unique -integer [$sel_frag get residue]]

    # Append all fragment residues
    lappend glycolipids_list {*}$frag_res

    $sel_frag delete
}

set glycolipids_list [lsort -unique -integer $glycolipids_list]

puts $outfile "\nRemoving [llength $glycolipids_residue] glycolipids (whole fragments):"
puts $outfile "$glycolipids_list"

###############################################################################
# FINAL REMOVAL AND STRUCTURE WRITING
###############################################################################

puts $outfile "\nTotal residues removed:"
puts $outfile "$lipids_residue $glycolipids_list"

close $outfile

# Write removed molecules (for inspection)
set removed_sel [atomselect top "residue $lipids_residue $glycolipids_list" frame last]
$removed_sel writejs removed_lipids_STEP-1_A.js
$removed_sel writenamdbin removed_lipids_STEP-1_A.coor

# Write cleaned structure
set cleaned_sel [atomselect top "not residue $lipids_residue $glycolipids_list" frame last]
$cleaned_sel writejs STEP-1_A_empty_holes_lipids.js
$cleaned_sel writenamdbin STEP-1_A_empty_holes_lipids.coor

puts "==> STEP-1_A lipid cleanup completed successfully."

quit                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              1,1           Top
