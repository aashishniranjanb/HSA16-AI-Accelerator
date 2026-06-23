#!/bin/bash
#===============================================================================
# HSA16 Master Automation Script - run_all.sh
# Target: Sequentially executes all six architectural flows
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

echo "==============================================================================="
echo " HSA16 MASTER RUN: Commencing full ASIC implementation flows"
echo "==============================================================================="

# Ensure all scripts are executable
chmod +x "flow/ASIC Flow Scripts"/run_baseline.sh
chmod +x "flow/ASIC Flow Scripts"/run_pe.sh
chmod +x "flow/ASIC Flow Scripts"/run_row.sh
chmod +x "flow/ASIC Flow Scripts"/run_tile.sh
chmod +x "flow/ASIC Flow Scripts"/run_hierarchical.sh
chmod +x "flow/ASIC Flow Scripts"/run_adaptive.sh

# Run scripts
"./flow/ASIC Flow Scripts"/run_baseline.sh
"./flow/ASIC Flow Scripts"/run_pe.sh
"./flow/ASIC Flow Scripts"/run_row.sh
"./flow/ASIC Flow Scripts"/run_tile.sh
"./flow/ASIC Flow Scripts"/run_hierarchical.sh
"./flow/ASIC Flow Scripts"/run_adaptive.sh

echo "==============================================================================="
echo " HSA16 MASTER RUN: All architecture implementation flows complete!"
echo " reports directory: flow/reports/"
echo " netlists directory: flow/netlists/"
echo " layout databases:  flow/innovus_db/"
echo "==============================================================================="
