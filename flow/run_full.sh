#!/bin/bash
#===============================================================================
# HSA16 Full ASIC Flow Runner (xrun -> SAIF -> Genus -> Innovus)
# Usage:
#   ./flow/run_full.sh <architecture>    Full flow for one arch
#   ./flow/run_full.sh --all             Full flow for all 6
#   ./flow/run_full.sh --skip-sim <arch> Skip xrun, run Genus + Innovus
#===============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -d "${SCRIPT_DIR}/../rtl" ]; then
    cd "$(cd "${SCRIPT_DIR}/.." && pwd)"
elif [ -d "${SCRIPT_DIR}/rtl" ]; then
    cd "${SCRIPT_DIR}"
fi

# Strip CRLF
find flow/ -name "*.sh" -exec sed -i 's/\r$//' {} + 2>/dev/null || true
find flow/ -name "*.tcl" -exec sed -i 's/\r$//' {} + 2>/dev/null || true

# Pass all arguments to run_genus.sh first
echo "=========================================="
echo " PHASE 1: Simulation + Genus Synthesis"
echo "=========================================="
bash flow/run_genus.sh "$@"

# Now run Innovus for same targets (strip --skip-sim flag)
echo ""
echo "=========================================="
echo " PHASE 2: Innovus Place & Route"
echo "=========================================="

# Build Innovus args (remove --skip-sim since it's irrelevant for Innovus)
INNOVUS_ARGS=()
for arg in "$@"; do
    if [ "$arg" != "--skip-sim" ]; then
        INNOVUS_ARGS+=("$arg")
    fi
done

bash flow/run_innovus.sh "${INNOVUS_ARGS[@]}"

echo ""
echo "==============================================================================="
echo " FULL ASIC FLOW COMPLETE"
echo " Reports:   flow/reports/genus/   and   flow/reports/innovus/"
echo " Netlists:  flow/netlists/"
echo " Layouts:   flow/innovus_db/"
echo "==============================================================================="
