###############################################################################
### LIPID SELECTION BETWEEN TWO CONCENTRIC SPHERES
###
### Purpose:
###   Identify and visualize lipid headgroups located between two concentric
###   spherical shells defined relative to the membrane radius. This is used
###   to quantify and inspect flipped lipids occupying putative membrane "holes" 
###   or clumps.
###
### Parameters:
###   d3, d4 : radial offsets (Å) from the membrane radius
###            (inner and outer bounds of the selection shell)
###
### Usage:
###   1) From the VMD Tk Console (or terminal), source the function:
###        source check_lipids_function.tcl
###
###   2) Run the function:
###        check_flipped_lipids d3 d4
###
### Notes:
###   - The membrane center and radius are estimated from selected lipid species.
###   - Lipid headgroups are selected if their radial distance from the membrane
###     center lies between (r_mem − d3) and (r_mem − d4).
###   - A VDW representation of the selected lipid heads is added for inspection.
###   - Try first with d3=20 and d4=40, then tweak the numbers as needed.
###
###############################################################################

proc check_lipids {d3 d4} {
    
    # --- Display settings for consistent visualization ---
    display depthcue off
    display resetview
    translate by 0.000000 0.000000 1.5000
    scale by 2.000000

    # --- Input sanity check ---
    if {$d3 < 0 || $d4 < 0} {
        error "d3 and d4 must be >= 0"
    }

    # --- Lipid macro ---
    atomselect macro lipid {
        resname DLPE DMPC DPPC GPC LPPC PALM PC PGCL POPC POPE POPS POPI POPI2A
        POPI24 PI2A PI24 PI25 CHL1 PSM LSM NSM CER1 TLCL TLCL2 BMGP
        SOPE SOPS SAPC SAPE SAPS SLPE SLPS PLPI DHPC C160 C240 PLA2 PPEE
    }

    # --- Clear previous graphics ---
    graphics top delete all

    # --- Select membrane lipids to define geometry ---
    set membrane [atomselect top "lipid"]
    if {[$membrane num] == 0} {
        error "No membrane lipids found — check selection."
    }

    # --- Membrane center of mass ---
    set com [measure center $membrane]
    lassign $com com_x com_y com_z

    # --- Bounding box → spherical approximation ---
    lassign [measure minmax $membrane] min max
    set diam [vecsub $max $min]
    set diam_avg [expr {([lindex $diam 0] + [lindex $diam 1] + [lindex $diam 2]) / 3.0}]
    set radius [expr {$diam_avg / 2.0}]

    # --- Radii for shells ---
    set r3 [expr {$radius - $d3}]
    set r4 [expr {$radius - $d4}]

    # --- Draw concentric spheres (blue, BlownGlass) ---
    graphics top color blue
    graphics top material BlownGlass
    graphics top sphere $com radius $r3 resolution 100
    graphics top sphere $com radius $r4 resolution 100

    # --- Define lipid headgroup universe ---
    set all_heads [atomselect top \
        "(name P) or (name O3 and resname CHL1) or (resname C160 C240 and name C1S)" \
        frame last]

    # --- Select lipid heads between shells ---
    set sel_heads [atomselect top \
        "((name P) or (name O3 and resname CHL1) or (resname C160 C240 and name C1S)) \
         and ((x-$com_x)*(x-$com_x) + (y-$com_y)*(y-$com_y) + (z-$com_z)*(z-$com_z)) < ($r3*$r3) \
         and ((x-$com_x)*(x-$com_x) + (y-$com_y)*(y-$com_y) + (z-$com_z)*(z-$com_z)) > ($r4*$r4)" \
         frame last]

    set sel_idx  [lsort -unique -integer [$sel_heads get index]]
    set sel_res  [lsort -unique -integer [$sel_heads get residue]]
    set n_sel    [llength $sel_res]

    # --- Report ---
    puts "========================================"
    puts "Lipid selection between concentric shells:"
    puts "  d3 offset: [format %.2f $d3] Å"
    puts "  d4 offset: [format %.2f $d4] Å"
    puts "  Membrane radius: [format %.2f $radius] Å"
    puts "  Number of flipped lipid residues: $n_sel"
    puts "========================================"

    # --- Hide existing reps ---
    set nreps [molinfo top get numreps]
    for {set i 0} {$i < $nreps} {incr i} {
        mol showrep top $i 0
    }

    # --- Representation: selected lipid heads ---
    mol color Name
    mol representation VDW 1.0 12.0
    mol selection "index $sel_idx"
    mol material AOChalky
    mol addrep top

    # --- Representation: non-selected lipid heads ---
    mol color ColorID 8
    mol representation VDW 0.7 10.0
    mol selection "index [$all_heads get index] and not index $sel_idx"
    mol material Opaque
    mol addrep top

    $membrane delete
    $all_heads delete
    $sel_heads delete
}

