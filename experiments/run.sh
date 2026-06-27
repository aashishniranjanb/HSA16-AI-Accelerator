#!/bin/bash
#===============================================================================
# HSA16 Gating Comparison Experiment Runner
# Usage:
#   ./run.sh <architecture> <step>
#
# Architectures:
#   hierarchical    (Static Hierarchical Gating)
#   adaptive        (Adaptive Gating - AHSA)
#
# Steps:
#   xrun            RTL simulation & SAIF generation
#   genus           Genus technology synthesis
#   innovus         Innovus place-and-route
#
# Examples:
#   ./run.sh hierarchical xrun
#   ./run.sh hierarchical genus
#   ./run.sh hierarchical innovus
#   ./run.sh adaptive xrun
#===============================================================================

set -euo pipefail

# Ensure script is run from experiments directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Print usage helper
usage() {
    echo "Usage: $0 {hierarchical|adaptive} {xrun|genus|innovus}"
    echo ""
    echo "Examples:"
    echo "  $0 hierarchical xrun"
    echo "  $0 adaptive genus"
    exit 1
}

# Check argument count
if [ $# -ne 2 ]; then
    usage
fi

ARCH="$1"
STEP="$2"

# Validate architecture
if [ "$ARCH" != "hierarchical" ] && [ "$ARCH" != "adaptive" ]; then
    echo "ERROR: Invalid architecture '$ARCH'. Must be 'hierarchical' or 'adaptive'."
    usage
fi

# Validate step
if [ "$STEP" != "xrun" ] && [ "$STEP" != "genus" ] && [ "$STEP" != "innovus" ]; then
    echo "ERROR: Invalid step '$STEP'. Must be 'xrun', 'genus', or 'innovus'."
    usage
fi

# Normalize paths for testbench and source files
declare -A TB_FILES
declare -A RTL_FILES

TB_FILES[hierarchical]="tb/hierarchical_gating/tb_b16_hierarchical.sv"
RTL_FILES[hierarchical]="rtl/common/hsa_params.svh rtl/hierarchical_gating/pe_hierarchical.sv rtl/hierarchical_gating/systolic16x16_hierarchical.sv"

TB_FILES[adaptive]="tb/adaptive_gating/tb_b16_adaptive.sv"
RTL_FILES[adaptive]="rtl/common/hsa_params.svh rtl/adaptive_gating/sparsity_estimator.sv rtl/adaptive_gating/gating_controller.sv rtl/adaptive_gating/pe_adaptive.sv rtl/adaptive_gating/systolic16x16_adaptive.sv"

# Make sure log and report output folders exist
mkdir -p flow/logs flow/reports/xrun flow/reports/genus flow/reports/innovus flow/netlists flow/innovus_db flow/xrun

# Strip Windows CRLF line endings from all scripts before running
find flow/ -name "*.tcl" -exec sed -i 's/\r$//' {} + 2>/dev/null || true

#-------------------------------------------------------------------------------
# STEP 1: Xrun Simulation & SAIF Generation
#-------------------------------------------------------------------------------
run_xrun() {
    echo "==============================================================================="
    echo " EXPERIMENT FLOW: [Architecture: $ARCH] -> [Step: Xrun Simulation]"
    echo "==============================================================================="
    
    local tb="${TB_FILES[$ARCH]}"
    local rtl="${RTL_FILES[$ARCH]}"
    local log_file="flow/logs/xrun_${ARCH}.log"
    local rep_log="flow/reports/xrun/${ARCH}.log"
    local vcd_file="flow/xrun/${ARCH}.vcd"
    local saif_file="flow/xrun/${ARCH}.saif"
    
    if ! command -v xrun &>/dev/null; then
        echo "ERROR: Cadence 'xrun' not found in PATH."
        exit 1
    fi
    
    local START_T=$(date +%s)
    
    # Run Xcelium RTL simulation
    # shellcheck disable=SC2086
    xrun -64bit -sv -timescale 1ns/1ps -access +rwc \
         -incdir rtl/common \
         $rtl "$tb" \
         -l "$log_file"
         
    local END_T=$(date +%s)
    echo "  Simulation finished in $((END_T - START_T)) seconds."
    
    # Copy log to reports directory
    cp "$log_file" "$rep_log"
    
    # Convert VCD -> SAIF for back-annotation
    if [ -f "$vcd_file" ]; then
        if command -v vcd2saif &>/dev/null; then
            echo "  Converting VCD to SAIF activity profile..."
            vcd2saif -input "$vcd_file" -output "$saif_file"
            echo "  SAIF generated successfully: $saif_file"
        else
            echo "  WARNING: 'vcd2saif' utility not in PATH. Power estimation will be vectorless."
        fi
    else
        echo "  WARNING: VCD dumpfile '$vcd_file' not found."
    fi
    
    echo "==============================================================================="
    echo " SUCCESS: Simulation step completed."
    echo "==============================================================================="
}

#-------------------------------------------------------------------------------
# STEP 2: Genus Technology Synthesis
#-------------------------------------------------------------------------------
run_genus() {
    echo "==============================================================================="
    echo " EXPERIMENT FLOW: [Architecture: $ARCH] -> [Step: Genus Synthesis]"
    echo "==============================================================================="
    
    local tcl_script="flow/genus/${ARCH}.tcl"
    local log_file="flow/logs/genus_${ARCH}.log"
    local saif_file="flow/xrun/${ARCH}.saif"
    
    if ! command -v genus &>/dev/null; then
        echo "ERROR: Cadence 'genus' not found in PATH."
        exit 1
    fi
    
    if [ ! -f "$tcl_script" ]; then
        echo "ERROR: Genus Tcl script not found: $tcl_script"
        exit 1
    fi
    
    if [ ! -f "$saif_file" ]; then
        echo "WARNING: SAIF file '$saif_file' not found. Synthesis will fall back to vectorless."
    fi
    
    local START_T=$(date +%s)
    
    # Execute Genus in batch mode
    genus -batch -f "$tcl_script" -log "$log_file"
    
    local END_T=$(date +%s)
    echo "  Synthesis finished in $((END_T - START_T)) seconds."
    
    local netlist="flow/netlists/${ARCH}_synth.v"
    if [ -f "$netlist" ]; then
        echo "  Synthesis netlist verified successfully: $netlist"
    else
        echo "  ERROR: Genus failed to output mapped netlist at: $netlist"
        exit 1
    fi
    
    echo "==============================================================================="
    echo " SUCCESS: Synthesis step completed."
    echo "==============================================================================="
}

#-------------------------------------------------------------------------------
# STEP 3: Innovus Place-and-Route (PnR)
#-------------------------------------------------------------------------------
run_innovus() {
    echo "==============================================================================="
    echo " EXPERIMENT FLOW: [Architecture: $ARCH] -> [Step: Innovus PnR]"
    echo "==============================================================================="
    
    local tcl_script="flow/innovus/${ARCH}.tcl"
    local log_file="flow/logs/innovus_${ARCH}.log"
    local netlist="flow/netlists/${ARCH}_synth.v"
    
    if ! command -v innovus &>/dev/null; then
        echo "ERROR: Cadence 'innovus' not found in PATH."
        exit 1
    fi
    
    if [ ! -f "$netlist" ]; then
        echo "ERROR: Missing synthesized netlist '$netlist'. Run Genus synthesis step first."
        exit 1
    fi
    
    if [ ! -f "$tcl_script" ]; then
        echo "ERROR: Innovus Tcl script not found: $tcl_script"
        exit 1
    fi
    
    local START_T=$(date +%s)
    
    # Execute Innovus in batch mode
    innovus -batch -f "$tcl_script" -log "$log_file"
    
    local END_T=$(date +%s)
    echo "  PnR finished in $((END_T - START_T)) seconds."
    
    echo "==============================================================================="
    echo " SUCCESS: Place-and-Route step completed."
    echo "==============================================================================="
}

# Execute target step
case "$STEP" in
    xrun)    run_xrun ;;
    genus)   run_genus ;;
    innovus) run_innovus ;;
esac
