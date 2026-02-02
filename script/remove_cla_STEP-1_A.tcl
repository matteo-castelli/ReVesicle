# Tcl script

mol new STEP-1_A_empty_holes_lipids.js waitfor all
mol addfile STEP-1_A_empty_holes_lipids.coor waitfor all

# CHECK IF OUTPUT TEXT FILE IS PRESENT
if { [file exists ./check_charge.txt] == 1} {puts "Output file is present. Eliminating it.."; exec rm ./check_charge.txt}

set outfile [open "check_charge.txt" w]

set tot_lipid_charge [vecsum [[atomselect top "lipid or glycan"] get charge]]
puts $outfile "Tot lipid charge is $tot_lipid_charge"

set cla_charge [vecsum [[atomselect top "resname CLA"] get charge]]
puts $outfile "Tot CLA charge is $cla_charge"

set sod_charge [vecsum [[atomselect top "resname SOD"] get charge]]
puts $outfile "Tot SOD charge is $sod_charge"

set net_charge [vecsum [[atomselect top "not water"] get charge]]
puts $outfile "net charge is = $net_charge"

set CLA_to_be_removed [expr {abs(int(round($net_charge)))}]

puts $outfile "Number of SOD/CLA to be removed: $CLA_to_be_removed"

# If nothing to remove: write full system and exit
if {$CLA_to_be_removed == 0} {
    puts $outfile "No ions need to be removed."
    close $outfile

    set remove_CLA [atomselect top "all"]
    $remove_CLA writejs STEP-1_A_empty_holes_lipids_charge.js
    $remove_CLA writenamdbin STEP-1_A_empty_holes_lipids_charge.coor
    exit
}

# Otherwise continue with original process
close $outfile

# Select all CLA atoms
if {$net_charge <= 0} {set ion "CLA"} else {set ion "SOD"}
set CLA [atomselect top "resname $ion"]
set CLA_list [lsort -real [$CLA get index]]
set CLA_list_length [llength [lsort -real [$CLA get index]]]

# Random number generation (Call this "myRand function when needed, without dollar")
set generatedNumbers {}

proc myRand {min max} {
    global generatedNumbers
    set range [expr {$max - $min + 1}]

    # Check if all numbers in the range have been generated
    if {[llength $generatedNumbers] == $range} {
        error "All numbers in the range have been generated."
    }

    # Generate a new random number that has not been used
    set number -1
    while {1} {
        set number [expr {$min + int(rand() * $range)}]
        if {[lsearch $generatedNumbers $number] == -1} {
            lappend generatedNumbers $number
            break
        }
    }

    return $number
}

set index_list []

for {set i 1} {$i <= $CLA_to_be_removed} {incr i} {

    set rand [myRand 0 $CLA_list_length]
    puts "atom $ion $rand will be removed"
    set CLA_rand [lindex $CLA_list $rand]
    lappend index_list $CLA_rand
}

set outfile2 [open "selected_CLA_SOD_indices.txt" w]
puts $outfile2 "Removing these $ion ions: index $index_list"

set CLA_input_read $index_list
set removed_CLA [atomselect top "index $CLA_input_read"]
set removed_CLA_llength [llength [lsort -real [$removed_CLA get index]]]
set remove_CLA [atomselect top "not index $CLA_input_read"]
set new_net_charge [vecsum [[atomselect top "not index $CLA_input_read"] get charge]]
puts $outfile2 "New charge after removing $removed_CLA_llength $ion is $new_net_charge"
close $outfile2

$remove_CLA writejs STEP-1_A_empty_holes_lipids_charge.js
$remove_CLA writenamdbin STEP-1_A_empty_holes_lipids_charge.coor


exit
