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
```
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
```
⚠️ Important
All input file paths must be provided as absolute paths.

---

## Repository structure
```
ReVesicle/
├── ReVesicle.sh
├── script/
├── CHARMM36m/
├── VMD_functions/
└── (run directories will be created here)
```

**Description**:

```
script/
```
Contains all VMD Tcl scripts, NAMD .conf files, and helper utilities required by the workflow.
These files are copied automatically into the appropriate STEP folders at runtime.

```
CHARMM36m/
```
⚠️ Required. Must be located at the top level of the repository. 
This directory should contain the CHARMM36m force field files referenced by the NAMD configuration files (e.g. parameter and topology files).
The protocol assumes relative paths to this directory inside the .conf files.

```
VMD_functions/
```
VMD Tcl helper functions used to define and visualize two concentric spheres
around a simulated vesicle (pre-loaded in VMD). These functions are designed
to help users determine the geometric parameters d1 and d2 required to
identify infiltrated water molecules during STEP 1 and/or STEP 4, as well as
d3 and d4 required to identify flipped lipid species.

When running the full protocol (-run_steps all), the following directory tree is created:
```
STEP-1-3_A/
├── STEP-1_A/
├── STEP-2_A/
├── STEP-3_A/
```
```
STEP-1-3_B/
├── STEP-1_B/
├── STEP-2_B/
├── STEP-3_B/
```
```
STEP-4/
STEP-5/
```
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

### Basic examples

**Example 1: Remove infiltrated water, perform all steps**

```bash
./ReVesicle.sh \
  -d1 16 -d2 46 \
  -js  /full/path/to/system.js \
  -dcd /full/path/to/trajectory.dcd \
  -xst /full/path/to/system.xst
```
This command runs the complete ReVesicle workflow by default, executing STEP 1
through STEP 5. The parameters `d1` (16) and `d2` (46) define two concentric
spherical cutoffs relative to the vesicle radius, which are used during
STEP 1A, STEP 1B, and STEP 4 to identify and remove infiltrated water molecules.
Values for `d1` and `d2` can be determined interactively using the VMD helper
function provided in `VMD_functions/two_concentric_sphere_selection_function.tcl`.
Lipid removal is disabled by default, so only water cleanup is performed.
Trajectories are stripped of water and ions as defined by the
default `striptraj` behavior (yes).

**Example 2: Remove infiltrated water *and* flipped lipids, stop after STEP 4**

```bash
./ReVesicle.sh \
  -d1 16 -d2 46 \
  -remove_lipids on \
  -d3 18 -d4 52 \
  -js  /full/path/to/system.js \
  -dcd /full/path/to/trajectory.dcd \
  -xst /full/path/to/system.xst \
  -run_steps 1234
  –striptraj no
```
This command runs the ReVesicle workflow through STEP 4 only, as specified by
`-run_steps 1234`. This mode is useful for validating membrane cleanup and
non-equilibrium MD steps prior to proceeding to STEP 5.
In addition to removing infiltrated water molecules using the
`d1` and `d2` spherical cutoffs, flipped lipid species are identified when
`-remove_lipids on` is enabled and removed using the lipid-specific offsets
`d3` and `d4`. Values for `d1` and `d2` can be determined interactively using the
VMD helper function provided in
`VMD_functions/two_concentric_sphere_selection_function.tcl`, while appropriate
values for `d3` and `d4` can be determined using the VMD helper script
`VMD_functions/check_flipped_lipids.tcl`. 
Stripped trajectories, where water and ions are removed are not generated, as defined by `-striptraj no`.


**Example 3: Chaining ReVesicle iterations**

To start a new ReVesicle iteration manually after the previous one (`iteration_1`) has finished, run `ReVesicle.sh` from the new iteration folder (`iteration_2`) using:

- `-js`  from the previous iteration `STEP-4` (`STEP-4_empty_holes.js`)
- `-dcd` from the previous iteration `STEP-5` trajectory (`STEP-5.dcd`)
- `-xst` from the previous iteration `STEP-5` cell (`STEP-5.xst`)

Project's main directory layout:

```
project/
├── iteration_1/
│   ├── ReVesicle.sh
│   ├── ...
│   ├── STEP-4/
│   │   └── STEP-4_empty_holes.js
│   └── STEP-5/
│       ├── STEP-5.dcd
│       └── STEP-5.xst
└── iteration_2/
    ├── ReVesicle.sh
    ├── Script
    ├── VMD_functions
    └── CHARMM36m
```
Note: make sure you have cloned the all the essential ReVesicle files and subdirectories (`ReVesicle.sh`, `Script`, `VMD_functions`, `CHARMM36m`) in the new iteration folder (`iteration_2`).

Example:

```bash
 # Move from iteration_1 to the new iteration folder
 cd ../iteration_2/

 # Run ReVesicle
 ./ReVesicle.sh \
  -d1 16 \
  -d2 46 \
  -js  ../iteration_1/STEP-4/STEP-4_empty_holes.js \
  -dcd ../iteration_1/STEP-5/STEP-5.dcd \
  -xst ../iteration_1/STEP-5/STEP-5.xst
```

---

## Notes

* The protocol assumes quasi-spherical vesicle geometries
* File naming consistency is enforced via environment variables
* Periodic box dimensions are automatically propagated from the provided `.xst` file

---

## Citation

If you use ReVesicle in published work, please cite the associated manuscript describing the protocol and validation.

