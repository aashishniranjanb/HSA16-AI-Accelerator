#!/bin/bash
#===============================================================================
# HSA16 Innovus PnR Runner
# Usage:
#   ./flow/run_innovus.sh <architecture>   Run Innovus PnR for one arch
#   ./flow/run_innovus.sh --all            Run Innovus for all 6
#
# Prerequisites: Genus netlist must exist at flow/netlists/<arch>_synth.v
#===============================================================================

set -euo pipefail

ALL_ARCHS="baseline pe_gating row_gating tile_gating hierarchical adaptive"

run_innovus() {
    local arch="$1"
    local netlist="flow/netlists/${arch}_synth.v"
    local tcl="flow/innovus/${arch}.tcl"

    echo ""
    echo "==============================================================================="
    echo " HSA16 INNOVUS PnR: ${arch}"
    echo "==============================================================================="

    if [ ! -f "$netlist" ]; then
        echo "ERROR: Netlist not found: ${netlist}"
        echo "       Run Genus first: ./flow/run_genus.sh ${arch}"
        return 1
    fi

    if [ ! -f "$tcl" ]; then
        echo "ERROR: Innovus Tcl script not found: ${tcl}"
        return 1
    fi

    mkdir -p flow/reports/innovus flow/innovus_db flow/logs

    echo "--> Running Innovus PnR (batch mode)..."
    local START=$(date +%s)

    innovus -batch -f "$tcl" -log "flow/logs/innovus_${arch}.log"

    local ELAPSED=$(( $(date +%s) - START ))
    echo "==============================================================================="
    echo " DONE: ${arch}  |  ${ELAPSED} sec ($(( ELAPSED / 60 )) min)"
    echo " Reports: flow/reports/innovus/${arch}_*.rpt"
    echo " Database: flow/innovus_db/${arch}_final.enc"
    echo "==============================================================================="
}

# Find project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -d "${SCRIPT_DIR}/../rtl" ]; then
    cd "$(cd "${SCRIPT_DIR}/.." && pwd)"
elif [ -d "${SCRIPT_DIR}/rtl" ]; then
    cd "${SCRIPT_DIR}"
fi

# Strip CRLF
find flow/ -name "*.tcl" -exec sed -i 's/\r$//' {} + 2>/dev/null || true

# Parse args
TARGETS=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --all)  TARGETS=($ALL_ARCHS); shift ;;
        pe)     TARGETS+=("pe_gating"); shift ;;
        row)    TARGETS+=("row_gating"); shift ;;
        tile)   TARGETS+=("tile_gating"); shift ;;
        baseline|pe_gating|row_gating|tile_gating|hierarchical|adaptive)
                TARGETS+=("$1"); shift ;;
        -h|--help)
            echo "Usage: $0 [--all] <arch...>"
            exit 0 ;;
        *)  echo "ERROR: Unknown arg '$1'"; exit 1 ;;
    esac
done

if [ ${#TARGETS[@]} -eq 0 ]; then
    echo "Usage: $0 [--all] <arch...>"
    exit 1
fi

GRAND_START=$(date +%s)
for arch in "${TARGETS[@]}"; do
    run_innovus "$arch"
done
GRAND_TOTAL=$(( $(date +%s) - GRAND_START ))

echo ""
echo "==============================================================================="
echo " ALL INNOVUS DONE | ${#TARGETS[@]} architectures | ${GRAND_TOTAL} sec"
echo "==============================================================================="
