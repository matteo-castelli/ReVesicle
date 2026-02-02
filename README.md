# ReVesicle

ReVesicle is an automated, iterative equilibration protocol for large-scale, quasi-spherical lipid vesicles at the all-atom (AA) level. It is designed to robustly restore bilayer continuity and density in vesicles generated from wrapped planar membranes, which often contain holes, infiltrated water molecules, and flipped lipids.

The protocol combines selective removal of infiltrated species, short non-equilibrium MD cycles, and anisotropic pressure equilibration. All steps are orchestrated by a single driver script (`ReVesicle.sh`) that stages inputs, enforces consistent file naming, updates periodic boundary conditions, and executes VMD and NAMD in the correct order.

---

## Requirements

* **VMD** (with Tcl support)
* **NAMD 3** (two builds recommended: standard + non-memory-optimized for compression)
* Bash shell (tested with `bash`)
* Standard Unix utilities (`cp`, `grep`, `chmod`)

---

## Workflow overview

1. **STEP-1** – Identification and removal of infiltrated water (and optionally flipped lipids)
2. **STEP-2** – Short restrained non-equilibrium MD 
3. **STEP-3** – Short restrained non-equilibrium MD 
4. **STEP-4** – Infiltrated water removal 
5. **STEP-5** – Anisotropic NPT equilibration 

---

## Usage:
  ./ReVesicle.sh [OPTIONS]

Required arguments:
  -d1 <N>            Inner selection offset
  -d2 <N>            Outer selection offset
  -js <file.js>      Full path to system.js
  -dcd <file.dcd>    Full path to trajectory.dcd
  -xst <file.xst>    Full path to extended system (.xst)

Optional arguments:
  -remove_lipids on|off
                     Enable removal of flipped lipids (default: off)
                     Requires -d3 and -d4 when enabled

  -d3 <N>            Inner offset for lipid removal (only if -remove_lipids on)
  -d4 <N>            Outer offset for lipid removal (only if -remove_lipids on)

  -striptraj yes|no  Strip water and ions from trajectories
                     Runs striptraj_STEP-*.tcl after STEP-2/3/5
                     (default: yes)

  -run_steps all|1234|5
                     all   : run all STEP(s) (default)
                     1234  : stop after STEP-4
                     5     : run STEP-5 only

  -h, --help         Show this help message and exit

⚠️ Important
All input file paths must be provided as absolute paths.

---

## Repository structure

script/
Contains all VMD Tcl scripts, NAMD .conf files, and helper utilities required by the workflow.
These files are copied automatically into the appropriate STEP folders at runtime.

CHARMM36m/ ⚠️ Required
Must be located at the top level of the repository.

This directory should contain the CHARMM36m force field files referenced by the NAMD configuration files (e.g. parameter and topology files).
The protocol assumes relative paths to this directory inside the .conf files.

ReVesicle/
├── ReVesicle.sh
├── script/
├── CHARMM36m/
└── (run directories will be created here)

When running the full protocol (-run_steps all), the following directory tree is created:

STEP-1-3_A/
├── STEP-1_A/
├── STEP-2_A/
├── STEP-3_A/

STEP-1-3_B/
├── STEP-1_B/
├── STEP-2_B/
├── STEP-3_B/

STEP-4/
STEP-5/

---

## Usage

Make the driver executable:

```bash
chmod +x ReVesicle.sh
```

Run without arguments to display help:

```bash
./ReVesicle.sh
```

### Basic example

```bash
./ReVesicle.sh \
  -d1 16 -d2 46 \
  -js /full/path/to/system.js \
  -dcd /full/path/to/trajectory.dcd \
  -xst /full/path/to/system.xst
```

This runs the full ReVesicle protocol (STEP-1 through STEP-5).

---

## Trajectory stripping

When `-striptraj yes` is enabled, ReVesicle runs step-specific Tcl scripts to generate solvent-free trajectories in:

* `STEP-2_A`
* `STEP-3_A`
* `STEP-2_B`
* `STEP-3_B`
* `STEP-5`

These scripts remove water and ions while preserving lipid and protein coordinates, producing lighter trajectories for analysis and visualization.

---

## Notes

* The protocol assumes quasi-spherical vesicle geometries
* File naming consistency is enforced via environment variables
* Periodic box dimensions are automatically propagated from the provided `.xst` file

---

## License

This project is intended for open scientific use. A permissive license (MIT or BSD) is recommended when releasing the public repository.

---

## Citation

If you use ReVesicle in published work, please cite the associated manuscript describing the protocol and validation.

