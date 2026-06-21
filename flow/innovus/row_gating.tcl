#===============================================================================
# Cadence Innovus PnR Script - Row Gating Architecture
# Target: HSA16 Systolic Accelerator
#===============================================================================

#-------------------------------------------------------------------------------
# 1. Parameter and File Path Configuration
#-------------------------------------------------------------------------------
set ARCH_NAME         "row_gating"
set DESIGN            "systolic16x16_row_gated"

# Automatically detect project root directory
if {[file exists "flow"]} {
    set PROJECT_ROOT [pwd]
} elseif {[file exists "../flow"]} {
    set PROJECT_ROOT [file normalize "[pwd]/.."]
} else {
    set PROJECT_ROOT [pwd]
}

set WORK_DIR          "${PROJECT_ROOT}/flow"
set NETLIST_FILE      "${WORK_DIR}/netlists/${ARCH_NAME}_synth.v"
set SDC_FILE          "${WORK_DIR}/netlists/${ARCH_NAME}_synth.sdc"
set REPORT_DIR        "${WORK_DIR}/reports/innovus"
set SAIF_FILE         "${WORK_DIR}/saif/${ARCH_NAME}.saif"
set INSTANCE_PATH     "tb_b16_row_gated/dut"

# Technology LEF and Standard Cell LEF paths
set TECH_LEF          "/home/Cadence/FOUNDRY/digital/45nm/dig/lef/tech.lef"
set CELL_LEF          "/home/Cadence/FOUNDRY/digital/45nm/dig/lef/cells.lef"
set LEF_FILES         [list $TECH_LEF $CELL_LEF]

# Foundry typical library path
set TARGET_CELL_LIB   "/home/Cadence/FOUNDRY/digital/45nm/dig/lib/typical.lib"

# Output database and directory structure
file mkdir $REPORT_DIR
file mkdir "${WORK_DIR}/innovus_db"

#-------------------------------------------------------------------------------
# 2. Design Import & Initialization
#-------------------------------------------------------------------------------
puts "INFO: Initializing design import variables..."
set init_gnd_net "VSS"
set init_vxd_net "VDD"
set init_verilog $NETLIST_FILE
set init_design_settop 1
set init_top_design $DESIGN
set init_lef_file $LEF_FILES
set init_timing_library $TARGET_CELL_LIB

puts "INFO: Importing design into Innovus..."
init_design

#-------------------------------------------------------------------------------
# 3. Floorplanning
#-------------------------------------------------------------------------------
puts "INFO: Creating initial floorplan..."
floorPlan -r 1.0 0.70 10.0 10.0 10.0 10.0

#-------------------------------------------------------------------------------
# 4. Power Planning (VDD/VSS Ring and Stripe Structure)
#-------------------------------------------------------------------------------
puts "INFO: Configuring global net connections..."
globalNetConnect VDD -type pgpin -pin VDD -inst *
globalNetConnect VSS -type pgpin -pin VSS -inst *
globalNetConnect VDD -type tiehi -inst *
globalNetConnect VSS -type tielo -inst *

puts "INFO: Adding core power rings..."
addRing -nets {VDD VSS} -width 2.0 -spacing 1.0 \
        -layer {top Metal5 bottom Metal5 left Metal6 right Metal6} \
        -around core -center 1

puts "INFO: Standard cell power rail routing (sroute)..."
sroute -connect {corePin}

#-------------------------------------------------------------------------------
# 5. Cell Placement
#-------------------------------------------------------------------------------
puts "INFO: Running standard cell placement and optimization..."
setPlaceMode -fp false
placeDesign

# Optimize timing and area post-placement
optDesign -preCTS

# Placement Congestion Report
puts "INFO: Generating placement congestion report..."
report_congestion -wirelength -outfile ${REPORT_DIR}/${ARCH_NAME}_congestion.rpt

#-------------------------------------------------------------------------------
# 6. Clock Tree Synthesis (CTS)
#-------------------------------------------------------------------------------
puts "INFO: Generating Clock Tree Specification..."
create_ccopt_clock_tree_spec

puts "INFO: Executing Clock Tree Synthesis (CTS)..."
ccopt_design

# Post-CTS timing optimization
optDesign -postCTS
optDesign -postCTS -hold

# Clock Tree Report
puts "INFO: Generating clock tree reports..."
report_ccopt_clock_trees -outfile ${REPORT_DIR}/${ARCH_NAME}_clock_trees.rpt

#-------------------------------------------------------------------------------
# 7. Routing (Detailed Route)
#-------------------------------------------------------------------------------
puts "INFO: Setting routing modes and routing design..."
setNanoRouteMode -drouteStartIteration default
routeDesign

# Post-route timing optimization
optDesign -postRoute
optDesign -postRoute -hold

#-------------------------------------------------------------------------------
# 8. Post-Route Extraction and Verification
#-------------------------------------------------------------------------------
puts "INFO: Extracting RC parasitic data..."
extractRC

puts "INFO: Performing physical verification checks..."
verifyGeometry -report ${REPORT_DIR}/${ARCH_NAME}_geom.rpt
verifyConnectivity -type all -report ${REPORT_DIR}/${ARCH_NAME}_conn.rpt

#-------------------------------------------------------------------------------
# 9. Dynamic Power Analysis with SAIF Back-Annotation
#-------------------------------------------------------------------------------
if {[file exists $SAIF_FILE]} {
    puts "INFO: Reading SAIF dynamic activity file for physical power estimation..."
    read_activity_file -format SAIF -scope $INSTANCE_PATH $SAIF_FILE
    set_power_analysis_mode -method dynamic
} else {
    puts "WARNING: SAIF file ${SAIF_FILE} not found. Running static power analysis."
    set_power_analysis_mode -method static
}
report_power -outfile ${REPORT_DIR}/${ARCH_NAME}_power.rpt

#-------------------------------------------------------------------------------
# 10. Generate Final Sign-Off Reports
#-------------------------------------------------------------------------------
puts "INFO: Generating final timing and area reports..."
timeDesign -postRoute -pathReports -drvReports -slackReports \
           -numPaths 50 -outDir ${REPORT_DIR}/timing_reports_${ARCH_NAME}

# Report Area to file
report_area > ${REPORT_DIR}/${ARCH_NAME}_area.rpt

# Save final database
puts "INFO: Saving physical layout database..."
saveDesign ${WORK_DIR}/innovus_db/${ARCH_NAME}_final.enc

puts "SUCCESS: Innovus physical design flow completed for ${ARCH_NAME}."
exit
