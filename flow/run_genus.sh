#!/bin/bash
#===============================================================================
# HSA16 Genus Synthesis Runner
# Usage:
#   ./flow/run_genus.sh <architecture>     Simulate + Synthesize one arch
#   ./flow/run_genus.sh --all              Simulate + Synthesize all 6
#   ./flow/run_genus.sh --skip-sim <arch>  Skip xrun, Genus only
#
# Architectures: baseline, pe_gating, row_gating, tile_gating,
#                hierarchical, adaptive
#===============================================================================

set -euo pipefail

#-------------------------------------------------------------------------------
# Architecture Configuration
#-------------------------------------------------------------------------------
declare -A ARCH_TB
declare -A ARCH_RTL

ARCH_TB[baseline]="tb/baseline/tb_b16.sv"
ARCH_RTL[baseline]="rtl/common/hsa_params.svh rtl/baseline/pe_baseline.sv rtl/baseline/systolic16x16_baseline.sv"

ARCH_TB[pe_gating]="tb/pe_gating/tb_b16_pe_gated.sv"
ARCH_RTL[pe_gating]="rtl/common/hsa_params.svh rtl/pe_gating/pe_gated.sv rtl/pe_gating/systolic16x16_pe_gated.sv"

ARCH_TB[row_gating]="tb/row_gating/tb_b16_row_gated.sv"
ARCH_RTL[row_gating]="rtl/common/hsa_params.svh rtl/row_gating/pe_row_gated.sv rtl/row_gating/systolic16x16_row_gated.sv"

ARCH_TB[tile_gating]="tb/tile_gating/tb_b16_tile_gated.sv"
ARCH_RTL[tile_gating]="rtl/common/hsa_params.svh rtl/tile_gating/pe_tile_gated.sv rtl/tile_gating/systolic16x16_tile_gated.sv"

ARCH_TB[hierarchical]="tb/hierarchical_gating/tb_b16_hierarchical.sv"
ARCH_RTL[hierarchical]="rtl/common/hsa_params.svh rtl/hierarchical_gating/pe_hierarchical.sv rtl/hierarchical_gating/systolic16x16_hierarchical.sv"

ARCH_TB[adaptive]="tb/adaptive_gating/tb_b16_adaptive.sv"
ARCH_RTL[adaptive]="rtl/common/hsa_params.svh rtl/adaptive_gating/sparsity_estimator.sv rtl/adaptive_gating/gating_controller.sv rtl/adaptive_gating/pe_adaptive.sv rtl/adaptive_gating/systolic16x16_adaptive.sv"

ALL_ARCHS="baseline pe_gating row_gating tile_gating hierarchical adaptive"

#-------------------------------------------------------------------------------
# Step 1: xrun simulation
#-------------------------------------------------------------------------------
run_sim() {
    local arch="$1"
    echo "--> [1/3] xrun simulation: ${arch}"
    local START=$(date +%s)

    # shellcheck disable=SC2086
    xrun -64bit -sv -timescale 1ns/1ps -access +rwc \
         -incdir rtl/common \
         ${ARCH_RTL[$arch]} "${ARCH_TB[$arch]}" \
         -l "flow/logs/xrun_${arch}.log"

    echo "    Done: $(( $(date +%s) - START )) sec"
}

#-------------------------------------------------------------------------------
# Step 2: VCD -> SAIF (best-effort, never fails the flow)
#-------------------------------------------------------------------------------
try_saif() {
    local arch="$1"
    local vcd="flow/xrun/${arch}.vcd"
    local saif="flow/xrun/${arch}.saif"

    echo "--> [2/3] VCD -> SAIF"
    if [ -f "$vcd" ] && command -v vcd2saif &>/dev/null; then
        vcd2saif -input "$vcd" -output "$saif"
        echo "    SAIF: ${saif}"
    else
        echo "    Skipped (no VCD or no vcd2saif). Vectorless power."
    fi
}

#-------------------------------------------------------------------------------
# Step 3: Genus synthesis (batch, no GUI)
#-------------------------------------------------------------------------------
run_genus() {
    local arch="$1"
    local tcl="flow/genus/${arch}.tcl"

    echo "--> [3/3] Genus synthesis: ${arch}"
    local START=$(date +%s)

    genus -batch -f "$tcl" -log "flow/logs/genus_${arch}.log"

    local ELAPSED=$(( $(date +%s) - START ))
    echo "    Done: ${ELAPSED} sec ($(( ELAPSED / 60 )) min)"

    if [ -f "flow/netlists/${arch}_synth.v" ]; then
        echo "    Netlist OK: flow/netlists/${arch}_synth.v"
    else
        echo "    WARNING: Netlist not found. Check flow/logs/genus_${arch}.log"
    fi
}

#-------------------------------------------------------------------------------
# Full flow for one architecture
#-------------------------------------------------------------------------------
run_flow() {
    local arch="$1"
    local skip_sim="${2:-false}"

    echo ""
    echo "==============================================================================="
    echo " HSA16 GENUS FLOW: ${arch}"
    echo "==============================================================================="
    local FLOW_START=$(date +%s)

    mkdir -p flow/xrun flow/logs flow/reports/genus flow/netlists

    if [ "$skip_sim" = "true" ]; then
        echo "--> [1/3] Simulation SKIPPED (--skip-sim)"
    else
        run_sim "$arch"
    fi

    try_saif "$arch"
    run_genus "$arch"

    local TOTAL=$(( $(date +%s) - FLOW_START ))
    echo "==============================================================================="
    echo " DONE: ${arch}  |  ${TOTAL} sec ($(( TOTAL / 60 )) min)"
    echo " Reports: flow/reports/genus/${arch}_*.rpt"
    echo "==============================================================================="
}

#-------------------------------------------------------------------------------
# Main
#-------------------------------------------------------------------------------
# Find project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -d "${SCRIPT_DIR}/../rtl" ]; then
    cd "$(cd "${SCRIPT_DIR}/.." && pwd)"
elif [ -d "${SCRIPT_DIR}/rtl" ]; then
    cd "${SCRIPT_DIR}"
fi

# Strip CRLF from scripts
find flow/ -name "*.sh" -exec sed -i 's/\r$//' {} + 2>/dev/null || true
find flow/ -name "*.tcl" -exec sed -i 's/\r$//' {} + 2>/dev/null || true

# Parse args
SKIP_SIM="false"
TARGETS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --all)       TARGETS=($ALL_ARCHS); shift ;;
        --skip-sim)  SKIP_SIM="true"; shift ;;
        pe)          TARGETS+=("pe_gating"); shift ;;
        row)         TARGETS+=("row_gating"); shift ;;
        tile)        TARGETS+=("tile_gating"); shift ;;
        baseline|pe_gating|row_gating|tile_gating|hierarchical|adaptive)
                     TARGETS+=("$1"); shift ;;
        -h|--help)
            echo "Usage: $0 [--skip-sim] [--all] <arch...>"
            echo "Archs: baseline pe_gating row_gating tile_gating hierarchical adaptive"
            echo "Short: pe row tile"
            exit 0 ;;
        *)  echo "ERROR: Unknown arg '$1'"; exit 1 ;;
    esac
done

if [ ${#TARGETS[@]} -eq 0 ]; then
    echo "Usage: $0 [--skip-sim] [--all] <arch...>"
    exit 1
fi

echo "==============================================================================="
echo " HSA16 Flow | Targets: ${TARGETS[*]} | Skip sim: ${SKIP_SIM}"
echo "==============================================================================="

GRAND_START=$(date +%s)
for arch in "${TARGETS[@]}"; do
    run_flow "$arch" "$SKIP_SIM"
done
GRAND_TOTAL=$(( $(date +%s) - GRAND_START ))

echo ""
echo "==============================================================================="
echo " ALL DONE | ${#TARGETS[@]} architectures | ${GRAND_TOTAL} sec ($(( GRAND_TOTAL / 60 )) min)"
echo "==============================================================================="
