# remove_water_STEP-1_B.tcl
#
# Purpose (ReVesicle STEP-1_B):
#   Identify infiltrated water molecules located in the membrane interior
#   (between two concentric spherical surfaces) and remove them.
#
# Inputs are provided by ReVesicle.sh via environment variables:
#   REVESICLE_D1   -> inner offset (Å)
#   REVESICLE_D2   -> outer offset (Å)
#
# Example CLI (handled by ReVesicle.sh):
#   ./ReVesicle.sh -d1 16 -d2 46 -js path/to/system.js -dcd path/to/traj.dcd
#
# Notes:
#   - d_mid is computed automatically:
#       d_mid = ((d2 - d1) / 2) + d1
#   - Selections are written as single long lines (no "\" line continuations).

###############################################################################
# READ INPUTS FROM ReVesicle.sh (ENVIRONMENT VARIABLES)
###############################################################################

# Required: d1 and d2 offsets
if {![info exists env(REVESICLE_D1)] || ![info exists env(REVESICLE_D2)]} {
  puts "ERROR: Missing REVESICLE_D1 and/or REVESICLE_D2 environment variables."
  puts "Run ReVesicle.sh like: ./ReVesicle.sh -d1 <value> -d2 <value>"
  quit
}
set d1 $env(REVESICLE_D1)
set d2 $env(REVESICLE_D2)

# Midpoint offset used to split inner vs outer water removal stats
set d_mid [expr {(($d2 - $d1)/2.0) + $d1}]

puts "==> Water-selection offsets:"
puts "    d1    = $d1"
puts "    d2    = $d2"
puts "    d_mid = $d_mid"

###############################################################################
# LOAD SYSTEM
###############################################################################

if {![info exists env(REVESICLE_STEP1A_BASENAME)]} {
    puts "ERROR: REVESICLE_STEP1A_BASENAME not set."
    puts "       This must be provided by ReVesicle.sh."
    exit 1
}

set basename $env(REVESICLE_STEP1A_BASENAME)

# STEP-1_A structure (relative path from STEP-1_B folder)
set js_file "../../STEP-1-3_A/STEP-1_A/${basename}.js"

puts "==> Loading STEP-1_A system:"
puts "    JS   = $js_file"

mol new $js_file waitfor all
mol addfile ../../STEP-1-3_A/STEP-3_A/STEP-3_A.dcd type dcd waitfor all

###############################################################################
# CLEANUP OLD OUTPUT FILES (IF PRESENT)
###############################################################################

if { [file exists ./TOT_output_water.txt] == 1} {puts "Output file is present. Eliminating it.."; exec rm ./TOT_output_water.txt}
if { [file exists ./IN_OUT_water_holes.txt] == 1} {puts "Output file is present. Eliminating it.."; exec rm ./IN_OUT_water_holes.txt}

###############################################################################
# OPEN OUTPUT FILES
###############################################################################
# TOT_output_water.txt:
#   list of selected water residue IDs (shell region)
# IN_OUT_output_water.txt:
#   counts (TOTAL, INNER, OUTER)

set outfile0 [open "TOT_output_water.txt" w]
set outfile1 [open "IN_OUT_output_water.txt" w]

atomselect macro glycan {resname NAG BGLN BGLCNA FUC AFUC BFUC AGAL BGAL MAN AMAN BMA BMAN BCNA ANE5 ANE5AC BNE5AC AGAN AGALNA AGALNAC BGLC BGAN AGAN}

atomselect macro lipid {resname DLPE DMPC DPPC GPC LPPC PALM PC PGCL POPC POPE POPS POPI POPI2A POPI24 PI2A PI24 PI25 CHL1 PSM LSM NSM CER1 TLCL TLCL2 BMGP SOPE SOPS SAPC SAPE SAPS SLPE SLPS PLPI DHPC C160 C240 PLA2 PPEE}

###############################################################################
# COMPUTE MEMBRANE COM + APPROXIMATE RADIUS
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
puts "    radius (avg/2) = $radius"

###############################################################################
# SELECT TOTAL WATER IN THE SHELL REGION (BETWEEN d1 AND d2)
###############################################################################
# Shell definition:
#   (radius - d2) < r < (radius - d1)

set TOT_sel "(resname TIP3 and same residue as (((x-$membrane_com_x)*(x-$membrane_com_x) + (y-$membrane_com_y)*(y-$membrane_com_y) + (z-$membrane_com_z)*(z-$membrane_com_z)) < (($radius-$d1)*($radius-$d1)) and ((x-$membrane_com_x)*(x-$membrane_com_x) + (y-$membrane_com_y)*(y-$membrane_com_y) + (z-$membrane_com_z)*(z-$membrane_com_z)) > (($radius-$d2)*($radius-$d2))))"

set TOT_water [atomselect top $TOT_sel frame last]
set TOT_water_index   [lsort -unique -real [$TOT_water get residue]]
set TOT_water_index_l [llength $TOT_water_index]

$TOT_water writejs TOT_removed_water.js

puts $outfile0 "$TOT_water_index"
close $outfile0

###############################################################################
# REMOVE WATER (BASED ON TOT_output_water.txt INDEX LIST)
###############################################################################
#   read "TOT_output_water.txt" and remove those indices from the structure.

set water_input [open "TOT_output_water.txt" r]
set water_input_read [read $water_input]
close $water_input

set remove_water [atomselect top "not index $water_input_read" frame last]
$remove_water writejs STEP-1_B_empty_holes.js
$remove_water writenamdbin STEP-1_B_empty_holes.coor

###############################################################################
# SPLIT SHELL WATER INTO INNER VS OUTER USING d_mid
###############################################################################
# INNER: r < (radius - d_mid)
# OUTER: r > (radius - d_mid)

set IN_sel  "($TOT_sel and (resname TIP3 and same residue as (((x-$membrane_com_x)*(x-$membrane_com_x) + (y-$membrane_com_y)*(y-$membrane_com_y) + (z-$membrane_com_z)*(z-$membrane_com_z)) < (($radius-$d_mid)*($radius-$d_mid)))))"
set OUT_sel "($TOT_sel and (resname TIP3 and same residue as (((x-$membrane_com_x)*(x-$membrane_com_x) + (y-$membrane_com_y)*(y-$membrane_com_y) + (z-$membrane_com_z)*(z-$membrane_com_z)) > (($radius-$d_mid)*($radius-$d_mid)))))"

set IN_water [atomselect top $IN_sel frame last]
set IN_water_index   [lsort -unique -real [$IN_water get residue]]
set IN_water_index_l [llength $IN_water_index]
$IN_water writejs IN_removed_water_1.js

set OUT_water [atomselect top $OUT_sel frame last]
set OUT_water_index   [lsort -unique -real [$OUT_water get residue]]
set OUT_water_index_l [llength $OUT_water_index]
$OUT_water writejs OUT_removed_water_1.js

###############################################################################
# WRITE SUMMARY COUNTS: TOTAL INNER OUTER
###############################################################################

puts $outfile1 "$TOT_water_index_l $IN_water_index_l $OUT_water_index_l"
close $outfile1

quit

