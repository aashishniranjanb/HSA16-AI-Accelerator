#!/bin/bash
#===============================================================================
# HSA16 Automation Script - run_adaptive.sh
# Target: Adaptive Gating Architecture (Simulation -> VCD -> SAIF -> Genus -> Innovus)
#===============================================================================

set -e

# Find project root (directory containing flow/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -d "${SCRIPT_DIR}/../../flow" ]; then
    PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
elif [ -d "${SCRIPT_DIR}/../flow" ]; then
    PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
else
    PROJECT_ROOT="${SCRIPT_DIR}"
fi
cd "${PROJECT_ROOT}"

ARCH="adaptive"
TB_FILE="tb/adaptive_gating/tb_b16_adaptive.sv"
RTL_FILES=(
    "rtl/common/hsa_params.svh"
    "rtl/adaptive_gating/sparsity_estimator.sv"
    "rtl/adaptive_gating/gating_controller.sv"
    "rtl/adaptive_gating/pe_adaptive.sv"
    "rtl/adaptive_gating/systolic16x16_adaptive.sv"
)

echo "==============================================================================="
echo " HSA16 FLOW MANAGER: Commencing flow for architecture: ${ARCH}"
echo "==============================================================================="

# 1. Check tool availability
command -v xrun >/dev/null 2>&1 || {
    echo "ERROR: Cadence simulator 'xrun' not found in PATH."
    echo "Please load the Xcelium module before running."
    exit 1
}

command -v genus >/dev/null 2>&1 || {
    echo "ERROR: Cadence synthesis tool 'genus' not found in PATH."
    echo "Please load the Genus module before running."
    exit 1
}

command -v innovus >/dev/null 2>&1 || {
    echo "ERROR: Cadence physical design tool 'innovus' not found in PATH."
    echo "Please load the Innovus module before running."
    exit 1
}

# 2. Create directory structure
mkdir -p flow/xrun flow/logs flow/reports/genus flow/reports/innovus flow/netlists flow/innovus_db

# 3. Step 1: RTL Simulation
echo "--> Step 1: Running RTL Simulation with xrun..."
START_SIM=$(date +%s)
xrun -64bit -sv -timescale 1ns/1ps -access +rwc -incdir rtl/common \
    "${RTL_FILES[@]}" "${TB_FILE}" \
    -l flow/logs/xrun_${ARCH}.log
END_SIM=$(date +%s)
TIME_SIM=$((END_SIM - START_SIM))
echo "    RTL Simulation Complete. Time: ${TIME_SIM} seconds."

# 4. Step 2: Convert VCD -> SAIF
echo "--> Step 2: Generating SAIF Activity Profile..."
VCD_FILE="flow/xrun/${ARCH}.vcd"
SAIF_FILE="flow/xrun/${ARCH}.saif"

if [ -f "$VCD_FILE" ]; then
    if command -v vcd2saif >/dev/null 2>&1; then
        vcd2saif -input "$VCD_FILE" -output "$SAIF_FILE"
        echo "    SAIF generation successful: ${SAIF_FILE}"
    else
        echo "    WARNING: 'vcd2saif' command not found in PATH."
        echo "    Skipping VCD to SAIF conversion. Synthesis/PnR will fall back to vectorless."
    fi
else
    echo "    ERROR: Expected VCD file '${VCD_FILE}' was not found. Simulation might have failed."
    exit 1
fi

# 5. Step 3: Genus Synthesis
echo "--> Step 3: Running Genus Synthesis..."
START_GENUS=$(date +%s)
genus -files flow/genus/${ARCH}.tcl -log flow/logs/genus_${ARCH}.log
END_GENUS=$(date +%s)
TIME_GENUS=$((END_GENUS - START_GENUS))
echo "    Genus Synthesis Complete. Time: ${TIME_GENUS} seconds."

# Check synthesis output netlist
NETLIST_FILE="flow/netlists/${ARCH}_synth.v"
if [ ! -f "$NETLIST_FILE" ]; then
    echo "    ERROR: Genus failed to output mapped netlist at '${NETLIST_FILE}'."
    exit 1
fi

# 6. Step 4: Innovus Physical Design (PnR)
echo "--> Step 4: Running Innovus Physical Design (PnR)..."
START_INNOVUS=$(date +%s)
innovus -files flow/innovus/${ARCH}.tcl -log flow/logs/innovus_${ARCH}.log
END_INNOVUS=$(date +%s)
TIME_INNOVUS=$((END_INNOVUS - START_INNOVUS))
echo "    Innovus PnR Complete. Time: ${TIME_INNOVUS} seconds."

echo "==============================================================================="
echo " HSA16 FLOW SUCCESS: Architecture: ${ARCH}"
echo "   Simulation Time:  ${TIME_SIM} sec"
echo "   Genus Synth Time: ${TIME_GENUS} sec"
echo "   Innovus PnR Time: ${TIME_INNOVUS} sec"
echo "   Total Flow Time:  $((TIME_SIM + TIME_GENUS + TIME_INNOVUS)) sec"
echo "==============================================================================="
