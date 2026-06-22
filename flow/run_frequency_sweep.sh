#!/bin/bash
#===============================================================================
# HSA16 Automation Script - Frequency Sweep
# Target: Automate synthesis (Genus) and physical design (Innovus)
#         across multiple clock periods: 3.0ns, 2.5ns, 2.0ns, 1.8ns, 1.6ns.
#===============================================================================

# Ensure the script is executed from the project root
if [ ! -d "flow" ]; then
    echo "ERROR: Run this script from the project root containing the 'flow' folder."
    exit 1
fi

# Default configuration
ARCHITECTURES=("baseline" "pe_gating" "row_gating" "tile_gating" "hierarchical" "adaptive")
PERIODS=("3.0" "2.5" "2.0" "1.8" "1.6")

echo "==============================================================================="
echo " HSA16 Automation: Starting Clock Period (Frequency) Sweep"
echo " Target periods: ${PERIODS[*]} ns"
echo " Targets: ${ARCHITECTURES[*]}"
echo "==============================================================================="

# Create log directory if it doesn't exist
mkdir -p flow/logs

for arch in "${ARCHITECTURES[@]}"; do
    echo "-------------------------------------------------------------------------------"
    echo " Running Sweep for Architecture: ${arch}"
    echo "-------------------------------------------------------------------------------"
    
    for p in "${PERIODS[@]}"; do
        echo "--> [Period: ${p}ns] Launching Genus Synthesis..."
        
        # Run Genus with environment variable CLK_PERIOD exported
        export CLK_PERIOD=$p
        genus -files flow/genus/${arch}.tcl -log flow/logs/genus_${arch}_${p}ns.log
        
        # Check if netlist was successfully generated before launching Innovus
        if [ -f "flow/netlists/${arch}_synth_${p}ns.v" ] || [ -f "flow/netlists/${arch}_synth.v" ]; then
            echo "--> [Period: ${p}ns] Netlist verified. Launching Innovus PnR..."
            innovus -files flow/innovus/${arch}.tcl -log flow/logs/innovus_${arch}_${p}ns.log
        else
            echo "ERROR: Genus failed to output netlist for ${arch} at ${p}ns. Skipping Innovus."
        fi
        
        echo ""
    done
done

echo "==============================================================================="
echo " HSA16 Automation: Sweep Complete!"
echo " Mapped netlists are in 'flow/netlists/'"
echo " Reports are located in 'flow/reports/genus/' and 'flow/reports/innovus/'"
echo " Layout databases are saved in 'flow/innovus_db/'"
echo "==============================================================================="
