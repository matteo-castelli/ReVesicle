#!/usr/bin/env bash
###############################################################################
# ReVesicle.sh
#
# Purpose:
#   Create the standard ReVesicle folder structure and run each STEP command
#   (VMD Tcl scripts and NAMD configurations) in the correct working directory.
#
# Notes:
#   - Edit the "USER SETTINGS" section before running.
#     (see "INPUT FILES EXPECTED" below).
#
# Usage:
#   chmod +x ReVesicle.sh
#   ./ReVesicle.sh
###############################################################################

set -euo pipefail

usage() {
  cat << EOF
Usage:
  ./ReVesicle.sh [OPTIONS]

Required arguments:
  -d1 <N>            Inner selection offset
  -d2 <N>            Outer selection offset
  -js <file.js>      Input structure (used only for STEP-1_A)
  -dcd <file.dcd>    Input trajectory (used only for STEP-1_A)
  -xst <file.xst>    Extended system file used to set PBC

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
                     all   : run full workflow (default)
                     1234  : stop after STEP-4
                     5     : run STEP-5 only

  -h, --help         Show this help message and exit

Examples:
  ./ReVesicle.sh -d1 16 -d2 46 -js system.js -dcd traj.dcd -xst run.xst
  ./ReVesicle.sh -d1 16 -d2 46 -js system.js -dcd traj.dcd -xst run.xst \\
                 -remove_lipids on -d3 20 -d4 32 -striptraj no
EOF
}

# If no arguments are provided, show help and exit
if [[ $# -eq 0 ]]; then
  usage
  exit 0
fi

###############################################################################
# CLI ARGUMENTS
###############################################################################
# -d1 / -d2 : selection offsets (used by STEP-1_A, STEP-1_B, STEP-4 water removal)
# -js / -dcd: input system/trajectory (used ONLY by remove_water_STEP-1_A.tcl)
# -xst      : input extended system file used to automatically set PBC lines in
#             selected .conf files (cellBasisVector1/2/3, cellOrigin)

D1=""
D2=""
STEP1A_JS=""
STEP1A_DCD=""
INPUT_XST=""
REMOVE_LIPIDS="off"
D3=""
D4=""
RUN_MODE="all"
STRIPTRAJ="yes"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    -d1)  D1="$2"; shift 2 ;;
    -d2)  D2="$2"; shift 2 ;;
    -js)  STEP1A_JS="$2"; shift 2 ;;
    -dcd) STEP1A_DCD="$2"; shift 2 ;;
    -xst) INPUT_XST="$2"; shift 2 ;;
    -remove_lipids) REMOVE_LIPIDS="$2"; shift 2 ;;
    -d3)  D3="$2"; shift 2 ;;
    -d4)  D4="$2"; shift 2 ;;
    -run_steps) RUN_MODE="$2"; shift 2 ;;
    -striptraj) STRIPTRAJ="$2"; shift 2 ;;
    *)
      echo "Unknown option: $1" >&2
      echo "Usage: ./ReVesicle.sh -d1 <N> -d2 <N> -js <file.js> -dcd <file.dcd> -xst <file.xst> [-striptraj yes|no] [-remove_lipids on|off -d3 <N> -d4 <N>] [-run_steps all|1234|5]" >&2
      exit 1
      ;;
  esac
done

# d1/d2 are required for all remove_water steps
if [[ -z "${D1}" || -z "${D2}" ]]; then
  echo "ERROR: missing -d1 and/or -d2" >&2
  echo "Usage: ./ReVesicle.sh -d1 <N> -d2 <N> -js <file.js> -dcd <file.dcd> -xst <file.xst> [-striptraj yes|no] [-remove_lipids on|off -d3 <N> -d4 <N>] [-run_steps all|1234|5]" >&2
  exit 1
fi

# js/dcd are required only for STEP-1_A remove_water
if [[ -z "${STEP1A_JS}" || -z "${STEP1A_DCD}" ]]; then
  echo "ERROR: missing -js and/or -dcd (required for STEP-1_A remove_water)" >&2
  echo "Usage: ./ReVesicle.sh -d1 <N> -d2 <N> -js <file.js> -dcd <file.dcd> -xst <file.xst> [-striptraj yes|no] [-remove_lipids on|off -d3 <N> -d4 <N>] [-run_steps all|1234|5]" >&2
  exit 1
fi

# xst is required for automatic PBC update
if [[ -z "${INPUT_XST}" ]]; then
  echo "ERROR: missing -xst (required to update cellBasisVector/cellOrigin in .conf files)" >&2
  echo "Usage: ./ReVesicle.sh -d1 <N> -d2 <N> -js <file.js> -dcd <file.dcd> -xst <file.xst> [-striptraj yes|no] [-remove_lipids on|off -d3 <N> -d4 <N>] [-run_steps all|1234|5]" >&2
  exit 1
fi

# Validate remove_lipids flag
if [[ "${REMOVE_LIPIDS}" != "on" && "${REMOVE_LIPIDS}" != "off" ]]; then
  echo "ERROR: -remove_lipids must be 'on' or 'off' (got: ${REMOVE_LIPIDS})" >&2
  exit 1
fi

# Validate striptraj flag
if [[ "${STRIPTRAJ}" != "yes" && "${STRIPTRAJ}" != "no" ]]; then
  echo "ERROR: -striptraj must be \'yes\' or \'no\' (got: ${STRIPTRAJ})" >&2
  exit 1
fi

echo "==> Strip trajectory step: ${STRIPTRAJ}"

# If enabled, require d3/d4 and export them for Tcl
if [[ "${REMOVE_LIPIDS}" == "on" ]]; then
  if [[ -z "${D3}" || -z "${D4}" ]]; then
    echo "ERROR: -remove_lipids on requires -d3 and -d4" >&2
    exit 1
  fi
  export REVESICLE_D3="${D3}"
  export REVESICLE_D4="${D4}"
  echo "==> Lipid removal enabled: d3=${REVESICLE_D3}, d4=${REVESICLE_D4}"
else
  echo "==> Lipid removal disabled"
fi

if [[ "${RUN_MODE}" != "all" && "${RUN_MODE}" != "1234" && "${RUN_MODE}" != "5" ]]; then
  echo "ERROR: -run must be one of: all | 1234 | 5 (got: ${RUN_MODE})" >&2
  exit 1
fi

echo "==> Run mode selected: ${RUN_MODE}"

# ---------------------------------------------------------------------------
# Define STEP-1_A system basename depending on lipid removal
# This controls which .js/.coor downstream scripts will read
# ---------------------------------------------------------------------------

if [[ "${REMOVE_LIPIDS}" == "on" ]]; then
  STEP1A_SYSTEM_BASENAME="STEP-1_A_empty_holes_lipids_charge"
else
  STEP1A_SYSTEM_BASENAME="STEP-1_A_empty_holes"
fi

export REVESICLE_STEP1A_BASENAME="${STEP1A_SYSTEM_BASENAME}"

echo "==> STEP-1_A system basename set to: ${REVESICLE_STEP1A_BASENAME}"
###############################################################################
# Sanity checks for STEP-1_A basename propagation
###############################################################################

echo "==> Sanity check: STEP-1_A basename propagation"

# Informative: what files downstream scripts are expected to read/write
echo "    Expected STEP-1_A outputs:"
echo "      ${REVESICLE_STEP1A_BASENAME}.js"
echo "      ${REVESICLE_STEP1A_BASENAME}.coor"
echo "      ${REVESICLE_STEP1A_BASENAME}.js.inter (after compress)"

# Defensive check: ensure conf files reference the environment variable
# (avoids silent hard-coded filename bugs)
# WORKDIR is defined later in USER SETTINGS; use safe fallback here
WORKDIR_EARLY="${WORKDIR:-$(pwd)}"

CONF_BASENAME_CHECK=(
  "${WORKDIR_EARLY}/STEP-1-3_A/STEP-1_A/compress_STEP-1_A.conf"
  "${WORKDIR_EARLY}/STEP-1-3_A/STEP-2_A/STEP-2_A.conf"
)

for conf in "${CONF_BASENAME_CHECK[@]}"; do
  if [[ -f "${conf}" ]]; then
    if grep -q "REVESICLE_STEP1A_BASENAME" "${conf}"; then
      echo "    OK: ${conf} uses REVESICLE_STEP1A_BASENAME"
    else
      echo "ERROR: ${conf} does NOT reference REVESICLE_STEP1A_BASENAME" >&2
      echo "       This likely means a hard-coded STEP-1_A_empty_holes*.js remains." >&2
      exit 1
    fi
  else
    echo "Checking basename: ${conf} will be copied to destination directory" >&2
  fi
done

[[ -f "${INPUT_XST}" ]] || { echo "ERROR: XST file not found: ${INPUT_XST}" >&2; exit 1; }

# Export d1/d2 globally so ALL VMD scripts can read them
export REVESICLE_D1="${D1}"
export REVESICLE_D2="${D2}"

echo "==> ReVesicle geometry (exported for all VMD steps): d1=${REVESICLE_D1}, d2=${REVESICLE_D2}"
echo "==> STEP-1_A input files (used only for remove_water_STEP-1_A.tcl):"
echo "    JS  = ${STEP1A_JS}"
echo "    DCD = ${STEP1A_DCD}"
echo "==> Input XST (used to update PBC in selected .conf files):"
echo "    XST = ${INPUT_XST}"

###############################################################################
# USER SETTINGS (EDIT THESE)
###############################################################################

# Path to your VMD executable (or just "vmd" if it's in your PATH)
VMD_BIN="${VMD_BIN:-vmd}"

# Path to your NAMD executable (or just "namd3" if it's in your PATH)
# Examples:
#   NAMD_BIN="/path/to/namd3"
#   NAMD_BIN="namd3"
NAMD_BIN="${NAMD_BIN:-/tmp/namd3}"

# Launcher command (e.g., ibrun, srun, mpirun). Empty = run NAMD directly.
NAMD_LAUNCHER="${NAMD_LAUNCHER:-ibrun}"

# Arguments that must appear BEFORE the .conf file (word-splitting intended)
NAMD_LAUNCH_ARGS="${NAMD_LAUNCH_ARGS:-+ppn 13 +pemap 4-55:2,5-55:2 +commap 0,2,1,3}"

# Root directory where the workflow folders will be created.
# Default: current directory.
WORKDIR="${WORKDIR:-$(pwd)}"

# ---------------------------------------------------------------------------
# NAMD settings for COMPRESS steps (genCompressedPsf / compress_*.conf)
# Some NAMD builds (e.g., memory-optimized) may not support these operations.
# By default, use the same launcher/args but allow a different binary.
# ---------------------------------------------------------------------------

# NAMD binary used ONLY for compress_* steps (e.g., a non-mem-optimized build)
NAMD_BIN_COMPRESS="${NAMD_BIN_COMPRESS:-/home1/05102/dhardy/frontera/namd_builds/NAMD_3.0b5_Linux-AVX512-MPI-smp/namd3}"

# Optional: launcher for compress runs (leave empty to run directly)
# Example: NAMD_LAUNCHER_COMPRESS=ibrun
NAMD_LAUNCHER_COMPRESS="${NAMD_LAUNCHER_COMPRESS:-ibrun}"

# Optional: mapping/flags for compress runs (defaults to same as regular)
NAMD_LAUNCH_ARGS_COMPRESS="${NAMD_LAUNCH_ARGS_COMPRESS:-}"

###############################################################################
# INPUT FILES EXPECTED
###############################################################################
# This script will RUN these in their corresponding step folders:
#
# STEP-1_A:
#   remove_water_STEP-1_A.tcl
#   print_index_water_lipids_heads_STEP-1_A.tcl
#   print_index_water_STEP-1_A.tcl
#   compress_STEP-1_A.conf
#
# STEP-2_A:
#   STEP-2_A.conf
#
# STEP-3_A:
#   STEP-3_A.conf
#
# STEP-1_B:
#   remove_water_STEP-1_B.tcl
#   print_index_water_lipids_heads_STEP-1_B.tcl
#   print_index_water_STEP-1_B.tcl
#   compress_STEP-1_B.conf
#
# STEP-2_B:
#   STEP-2_B.conf
#
# STEP-3_B:
#   STEP-3_B.conf
#
#  STEP-4:
#   remove_water_STEP-4.tcl
#   print_index_lipids_heads_STEP-4.tcl
#   compress_STEP-4.conf
#
# STEP-5:
#   STEP-5.conf
#
# Additionally required in ./script for automatic PBC update:
#   get_cell_size.sh
#
###############################################################################
# Helper functions
###############################################################################

die() {
  echo "ERROR: $*" >&2
  exit 1
}

run_vmd_tcl() {
  # Arguments:
  #   1) tcl_script
  #   2) log_file
  #   3) (optional) js_path   -> exported as REVESICLE_JS for this call only
  #   4) (optional) dcd_path  -> exported as REVESICLE_DCD for this call only
  local tcl_script="$1"
  local log_file="$2"
  local js_path="${3:-}"
  local dcd_path="${4:-}"

  [[ -f "$tcl_script" ]] || die "Missing Tcl script: $(pwd)/$tcl_script"

  echo "  -> VMD: $tcl_script (log: $log_file)"

  # If JS/DCD were provided, set them ONLY for this VMD process.
  # d1/d2 stay global because they are exported earlier.
  if [[ -n "$js_path" && -n "$dcd_path" ]]; then
    REVESICLE_JS="$js_path" REVESICLE_DCD="$dcd_path" \
      "${VMD_BIN}" -dispdev text -e "${tcl_script}" > "${log_file}" 2>&1
  else
    "${VMD_BIN}" -dispdev text -e "${tcl_script}" > "${log_file}" 2>&1
  fi
}

run_namd_conf() {
  # Arguments:
  #   1) conf_file
  #   2) log_file
  local conf_file="$1"
  local log_file="$2"

  [[ -f "$conf_file" ]] || die "Missing NAMD config: $(pwd)/$conf_file"

  echo "  -> NAMD: $conf_file (log: $log_file)"

  # Build command line
  local cmd=()

  # Optional launcher (e.g., ibrun)
  if [[ -n "${NAMD_LAUNCHER}" ]]; then
    cmd+=( "${NAMD_LAUNCHER}" )
  fi

  # NAMD binary
  cmd+=( "${NAMD_BIN}" )

  # Launcher/binary args that must precede the conf file (word-splitting intended)
  if [[ -n "${NAMD_LAUNCH_ARGS}" ]]; then
    # shellcheck disable=SC2206
    cmd+=( ${NAMD_LAUNCH_ARGS} )
  fi

  # Optional extra args (if you still want them)
  if [[ -n "${NAMD_EXTRA_ARGS:-}" ]]; then
    # shellcheck disable=SC2206
    cmd+=( ${NAMD_EXTRA_ARGS} )
  fi

  # Append config file last
  cmd+=( "${conf_file}" )

  # Run, redirect stdout+stderr
  "${cmd[@]}" > "${log_file}" 2>&1
  echo "    CMD: ${cmd[*]}"
}

run_namd_compress() {
  # Arguments:
  #   1) conf_file
  #   2) log_file
  local conf_file="$1"
  local log_file="$2"

  [[ -f "$conf_file" ]] || die "Missing NAMD config: $(pwd)/$conf_file"

  echo "  -> NAMD (compress): $conf_file (log: $log_file)"

  local cmd=()

  # Optional launcher (e.g., ibrun)
  if [[ -n "${NAMD_LAUNCHER_COMPRESS}" ]]; then
    cmd+=( "${NAMD_LAUNCHER_COMPRESS}" )
  fi

  # Compress NAMD binary (non-mem-optimized)
  cmd+=( "${NAMD_BIN_COMPRESS}" )

  # Launcher args before conf
  if [[ -n "${NAMD_LAUNCH_ARGS_COMPRESS}" ]]; then
    # shellcheck disable=SC2206
    cmd+=( ${NAMD_LAUNCH_ARGS_COMPRESS} )
  fi

  # Optional extra args (reuse same hook)
  if [[ -n "${NAMD_EXTRA_ARGS:-}" ]]; then
    # shellcheck disable=SC2206
    cmd+=( ${NAMD_EXTRA_ARGS} )
  fi

  cmd+=( "${conf_file}" )

  "${cmd[@]}" > "${log_file}"
  echo "    CMD: ${cmd[*]}"
}

###############################################################################
# Folder structure creation
###############################################################################

echo "==> Creating ReVesicle folder structure in: ${WORKDIR}"
cd "${WORKDIR}"

# Top-level folders
if [[ "${RUN_MODE}" != "5" ]]; then
  mkdir -p \
    "STEP-1-3_A/STEP-1_A" \
    "STEP-1-3_A/STEP-2_A" \
    "STEP-1-3_A/STEP-3_A" \
    "STEP-1-3_B/STEP-1_B" \
    "STEP-1-3_B/STEP-2_B" \
    "STEP-1-3_B/STEP-3_B" \
    "STEP-4"
fi

# STEP-5 directory is needed for mode "all" and "5"
if [[ "${RUN_MODE}" == "all" || "${RUN_MODE}" == "5" ]]; then
  mkdir -p "STEP-5"
fi

echo "==> Folder structure created."

###############################################################################
# NEW: Stage/copy input scripts from ./script into the correct folders
###############################################################################
SCRIPTS_DIR="${WORKDIR}/script"
[[ -d "${SCRIPTS_DIR}" ]] || die "Missing required folder: ${SCRIPTS_DIR}"

if [[ "${RUN_MODE}" != "5" ]]; then
 # Copy (overwrite) each required input file into its corresponding step folder.
 # This ensures each step directory is self-contained and runnable.
 cp -f "${SCRIPTS_DIR}/remove_water_STEP-1_A.tcl"                   "${WORKDIR}/STEP-1-3_A/STEP-1_A/"
 cp -f "${SCRIPTS_DIR}/print_index_water_lipids_heads_STEP-1_A.tcl" "${WORKDIR}/STEP-1-3_A/STEP-1_A/"
 cp -f "${SCRIPTS_DIR}/print_index_water_STEP-1_A.tcl"              "${WORKDIR}/STEP-1-3_A/STEP-1_A/"
 cp -f "${SCRIPTS_DIR}/compress_STEP-1_A.conf"                      "${WORKDIR}/STEP-1-3_A/STEP-1_A/"

 cp -f "${SCRIPTS_DIR}/STEP-2_A.conf"                               "${WORKDIR}/STEP-1-3_A/STEP-2_A/"
 cp -f "${SCRIPTS_DIR}/STEP-3_A.conf"                               "${WORKDIR}/STEP-1-3_A/STEP-3_A/"

 cp -f "${SCRIPTS_DIR}/remove_water_STEP-1_B.tcl"                   "${WORKDIR}/STEP-1-3_B/STEP-1_B/"
 cp -f "${SCRIPTS_DIR}/print_index_water_lipids_heads_STEP-1_B.tcl" "${WORKDIR}/STEP-1-3_B/STEP-1_B/"
 cp -f "${SCRIPTS_DIR}/print_index_water_STEP-1_B.tcl"              "${WORKDIR}/STEP-1-3_B/STEP-1_B/"
 cp -f "${SCRIPTS_DIR}/compress_STEP-1_B.conf"                      "${WORKDIR}/STEP-1-3_B/STEP-1_B/"

 cp -f "${SCRIPTS_DIR}/STEP-2_B.conf"                               "${WORKDIR}/STEP-1-3_B/STEP-2_B/"
 cp -f "${SCRIPTS_DIR}/STEP-3_B.conf"                               "${WORKDIR}/STEP-1-3_B/STEP-3_B/"

 # Optional: stage trajectory stripping Tcl scripts
 if [[ "${STRIPTRAJ}" == "yes" ]]; then
   cp -f "${SCRIPTS_DIR}/striptraj_STEP-2_A.tcl" "${WORKDIR}/STEP-1-3_A/STEP-2_A/"
   cp -f "${SCRIPTS_DIR}/striptraj_STEP-3_A.tcl" "${WORKDIR}/STEP-1-3_A/STEP-3_A/"
   cp -f "${SCRIPTS_DIR}/striptraj_STEP-2_B.tcl" "${WORKDIR}/STEP-1-3_B/STEP-2_B/"
   cp -f "${SCRIPTS_DIR}/striptraj_STEP-3_B.tcl" "${WORKDIR}/STEP-1-3_B/STEP-3_B/"
 fi

 cp -f "${SCRIPTS_DIR}/remove_water_STEP-4.tcl"                     "${WORKDIR}/STEP-4/"
 cp -f "${SCRIPTS_DIR}/print_index_lipids_heads_STEP-4.tcl"         "${WORKDIR}/STEP-4/"
 cp -f "${SCRIPTS_DIR}/compress_STEP-4.conf"                        "${WORKDIR}/STEP-4/"

fi

if [[ "${RUN_MODE}" != "5" && "${REMOVE_LIPIDS}" == "on" ]]; then
  cp -f "${SCRIPTS_DIR}/remove_lipids_STEP-1_A.tcl" "${WORKDIR}/STEP-1-3_A/STEP-1_A/"
  cp -f "${SCRIPTS_DIR}/remove_cla_STEP-1_A.tcl"    "${WORKDIR}/STEP-1-3_A/STEP-1_A/"
fi

if [[ "${RUN_MODE}" == "all" || "${RUN_MODE}" == "5" ]]; then
  cp -f "${SCRIPTS_DIR}/STEP-5.conf"      "${WORKDIR}/STEP-5/"
  
  if [[ "${RUN_MODE}" == "all" || "${RUN_MODE}" == "5" ]]; then
    cp -f "${SCRIPTS_DIR}/get_cell_size.sh" "${WORKDIR}/STEP-5/"
    chmod +x "${WORKDIR}/STEP-5/get_cell_size.sh"
  fi

  if [[ "${STRIPTRAJ}" == "yes" ]]; then
    cp -f "${SCRIPTS_DIR}/striptraj_STEP-5.tcl" "${WORKDIR}/STEP-5/"
  fi
fi

echo "==> Input files copied from ${SCRIPTS_DIR} into step folders."

###############################################################################
# NEW: Update PBC in selected .conf files from the provided .xst
###############################################################################

echo "==> Updating cellBasisVector/cellOrigin in selected .conf files from XST: ${INPUT_XST}"

CELL_HELPER="${SCRIPTS_DIR}/get_cell_size.sh"
chmod +x "${CELL_HELPER}"
[[ -x "${CELL_HELPER}" ]] || die "Missing or non-executable helper: ${CELL_HELPER}"

CONF_FILES_TO_UPDATE=()

if [[ "${RUN_MODE}" != "5" ]]; then
  CONF_FILES_TO_UPDATE+=(
    "${WORKDIR}/STEP-1-3_A/STEP-1_A/compress_STEP-1_A.conf"
    "${WORKDIR}/STEP-1-3_B/STEP-1_B/compress_STEP-1_B.conf"
    "${WORKDIR}/STEP-4/compress_STEP-4.conf"
    "${WORKDIR}/STEP-1-3_A/STEP-2_A/STEP-2_A.conf"
    "${WORKDIR}/STEP-1-3_B/STEP-2_B/STEP-2_B.conf"
  )
fi

if [[ "${RUN_MODE}" == "all" || "${RUN_MODE}" == "5" ]]; then
  CONF_FILES_TO_UPDATE+=( "${WORKDIR}/STEP-5/STEP-5.conf" )
fi

for conf in "${CONF_FILES_TO_UPDATE[@]}"; do
  [[ -f "${conf}" ]] || die "Missing conf to update: ${conf}"
  echo "  -> Updating: ${conf}"
  "${CELL_HELPER}" "${INPUT_XST}" "${conf}"
done

echo "==> Cell dimensions updated in all target .conf files."

###############################################################################
# Execution: STEP-1 → STEP-4
###############################################################################

if [[ "${RUN_MODE}" != "5" ]]; then

###############################################################################
# STEP-1-3_A
###############################################################################

 echo "==> Running STEP-1_A"
 cd "${WORKDIR}/STEP-1-3_A/STEP-1_A"
 run_vmd_tcl "remove_water_STEP-1_A.tcl" "remove_water_STEP-1_A.log" "${STEP1A_JS}" "${STEP1A_DCD}"

 if [[ "${REMOVE_LIPIDS}" == "on" ]]; then
   run_vmd_tcl "remove_lipids_STEP-1_A.tcl" "remove_lipids_STEP-1_A.log"
   run_vmd_tcl "remove_cla_STEP-1_A.tcl"    "remove_cla_STEP-1_A.log"
 fi

 run_vmd_tcl "print_index_water_lipids_heads_STEP-1_A.tcl" "print_index_water_lipids_heads_STEP-1_A.log"
 run_vmd_tcl "print_index_water_STEP-1_A.tcl" "print_index_water_STEP-1_A.log"

 run_namd_compress "compress_STEP-1_A.conf" "compress_STEP-1_A.log"

 echo "==> Running STEP-2_A"
 cd "${WORKDIR}/STEP-1-3_A/STEP-2_A"
 run_namd_conf "STEP-2_A.conf" "STEP-2_A.log"


 if [[ "${STRIPTRAJ}" == "yes" ]]; then
   echo "==> Stripping trajectory (STEP-2_A)"
   run_vmd_tcl "striptraj_STEP-2_A.tcl" "striptraj_STEP-2_A.log"
 fi

 echo "==> Running STEP-3_A"
 cd "${WORKDIR}/STEP-1-3_A/STEP-3_A"
 run_namd_conf "STEP-3_A.conf" "STEP-3_A.log"


 if [[ "${STRIPTRAJ}" == "yes" ]]; then
   echo "==> Stripping trajectory (STEP-3_A)"
   run_vmd_tcl "striptraj_STEP-3_A.tcl" "striptraj_STEP-3_A.log"
 fi

###############################################################################
# STEP-1-3_B
###############################################################################

 echo "==> Running STEP-1_B"
 cd "${WORKDIR}/STEP-1-3_B/STEP-1_B"
 run_vmd_tcl "remove_water_STEP-1_B.tcl" "remove_water_STEP-1_B.log"
 run_vmd_tcl "print_index_water_lipids_heads_STEP-1_B.tcl" "print_index_water_lipids_heads_STEP-1_B.log"
 run_vmd_tcl "print_index_water_STEP-1_B.tcl" "print_index_water_STEP-1_B.log"
 run_namd_compress "compress_STEP-1_B.conf" "compress_STEP-1_B.log"

 echo "==> Running STEP-2_B"
 cd "${WORKDIR}/STEP-1-3_B/STEP-2_B"
 run_namd_conf "STEP-2_B.conf" "STEP-2_B.log"


 if [[ "${STRIPTRAJ}" == "yes" ]]; then
   echo "==> Stripping trajectory (STEP-2_B)"
   run_vmd_tcl "striptraj_STEP-2_B.tcl" "striptraj_STEP-2_B.log"
 fi

 echo "==> Running STEP-3_B"
 cd "${WORKDIR}/STEP-1-3_B/STEP-3_B"
 run_namd_conf "STEP-3_B.conf" "STEP-3_B.log"


 if [[ "${STRIPTRAJ}" == "yes" ]]; then
   echo "==> Stripping trajectory (STEP-3_B)"
   run_vmd_tcl "striptraj_STEP-3_B.tcl" "striptraj_STEP-3_B.log"
 fi

###############################################################################
# STEP-4
###############################################################################

 echo "==> Running STEP-4"
 cd "${WORKDIR}/STEP-4"
 run_vmd_tcl "remove_water_STEP-4.tcl" "remove_water_STEP-4.log"
 run_vmd_tcl "print_index_lipids_heads_STEP-4.tcl" "print_index_lipids_heads_STEP-4.log"
 run_namd_compress "compress_STEP-4.conf" "compress_STEP-4.log"

fi  # end RUN_MODE != 5

if [[ "${RUN_MODE}" == "1234" ]]; then
  echo "==> Run mode 1234 selected: stopping after STEP-4."
  echo "==> ReVesicle workflow complete (STEP-1 through STEP-4)."
  exit 0
fi

###############################################################################
# STEP-5
###############################################################################

if [[ "${RUN_MODE}" == "5" ]]; then
  echo "==> Run mode 5 selected: running STEP-5 only."
fi

echo "==> Running STEP-5"
cd "${WORKDIR}/STEP-5"
run_namd_conf "STEP-5.conf" "STEP-5.conf.log"

if [[ "${STRIPTRAJ}" == "yes" ]]; then
  echo "==> Stripping trajectory (STEP-3_B)"
  run_vmd_tcl "striptraj_STEP-5.tcl" "striptraj_STEP-5.log"
fi

###############################################################################
# Done
###############################################################################

echo "==> ReVesicle workflow complete."

