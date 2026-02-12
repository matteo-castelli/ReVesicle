###############################################################################
### TWO-CONCENTRIC-SPHERE SELECTION FUNCTION
###
### Parameters:
###   d1, d2      : radial offsets (Å)
###   reset_view  : optional ("yes" | "no")
###                 yes = reset/translate/scale (default)
###                 no  = preserve current view (redraw spheres only)
###
### Usage:
###   draw_spheres 16 52
###   draw_spheres 16 52 no
###############################################################################

proc draw_spheres {d1 d2 {reset_view "yes"}} {

    # --- Validate reset_view argument ---
    if {$reset_view ne "yes" && $reset_view ne "no"} {
        error "reset_view must be 'yes' or 'no'"
    }

    # --- Display settings (only if reset_view == yes) ---
    if {$reset_view eq "yes"} {
        display depthcue off
        display resetview
        translate by 0.000000 0.000000 1.5000
        scale by 2.000000
    }

    # --- Input sanity check ---
    if {$d1 < 0 || $d2 < 0} {
        error "d1 and d2 must be >= 0"
    }

    # --- Lipid selection macro ---
    atomselect macro lipid {
        resname DLPE DMPC DPPC GPC LPPC PALM PC PGCL POPC POPE POPS POPI POPI2A
        POPI24 PI2A PI24 PI25 CHL1 PSM LSM NSM CER1 TLCL TLCL2 BMGP
        SOPE SOPS SAPC SAPE SAPS SLPE SLPS PLPI DHPC C160 C240 PLA2 PPEE
    }

    graphics top delete all

    # --- Select membrane ---
    set membrane [atomselect top "lipid"]
    if {[$membrane num] == 0} {
        error "No lipid atoms found — check topology or macro."
    }

    # --- Center of mass ---
    set com [measure center $membrane]

    # --- Bounding box ---
    lassign [measure minmax $membrane] min max
    set diam [vecsub $max $min]

    # --- Average diameter → spherical approximation ---
    set diam_avg [expr {([lindex $diam 0] + [lindex $diam 1] + [lindex $diam 2]) / 3.0}]
    set radius [expr {$diam_avg / 2.0}]

    # --- Radii ---
    set r1 [expr {$radius - $d1}]
    set r2 [expr {$radius - $d2}]

    if {$r1 <= 0 || $r2 <= 0} {
        error "Computed sphere radius <= 0. Check d1/d2."
    }

    # --- Draw spheres ---
    graphics top color blue
    graphics top material BlownGlass
    graphics top sphere $com radius $r1 resolution 100
    graphics top sphere $com radius $r2 resolution 100

    # --- Hide existing reps ---
    set nreps [molinfo top get numreps]
    for {set i 0} {$i < $nreps} {incr i} {
        mol showrep top $i 0
    }

    # --- Add CHL1 O3 representation ---
    mol representation VDW
    mol selection "resname CHL1 and name O3"
    mol color Name
    mol addrep top

    # --- Recap ---
    puts "========================================"
    puts "Two-concentric-sphere selection recap:"
    puts "  d1 offset: [format %.2f $d1] Å"
    puts "  d2 offset: [format %.2f $d2] Å"
    puts "  Membrane radius: [format %.2f $radius] Å"
    puts "  Sphere radii:"
    puts "    r1 = r_mem - d1 = [format %.2f $r1] Å"
    puts "    r2 = r_mem - d2 = [format %.2f $r2] Å"
    puts "========================================"

    $membrane delete
}

