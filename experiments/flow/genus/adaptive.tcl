#===============================================================================
# Cadence Genus Synthesis Script - Adaptive Gating Architecture
# Target: HSA16 Systolic Accelerator
# Optimized for speed: medium effort, 8 CPU cores, HDL search path
#===============================================================================

#-------------------------------------------------------------------------------
# 1. Parameter and Path Setup
#-------------------------------------------------------------------------------
set ARCH_NAME         "adaptive"
set DESIGN            "systolic16x16_adaptive"

# Automatically detect project root directory
if {[file exists "flow"]} {
    set PROJECT_ROOT [pwd]
} elseif {[file exists "../flow"]} {
    set PROJECT_ROOT [file normalize "[pwd]/.."]
} else {
    set PROJECT_ROOT [pwd]
}

set WORK_DIR          "${PROJECT_ROOT}/flow"
set NETLIST_DIR       "${WORK_DIR}/netlists"
set REPORT_DIR        "${WORK_DIR}/reports/genus"
set LOG_DIR           "${WORK_DIR}/logs"
set SDC_FILE          "${WORK_DIR}/constraints/systolic16x16.sdc"
set SAIF_FILE         "${WORK_DIR}/xrun/${ARCH_NAME}.saif"
set INSTANCE_PATH     "tb_b16_adaptive/dut"

# Foundry 45nm typical library path
set TARGET_CELL_LIB   "typical.lib"
set LIB_SEARCH_PATH   "/home/Cadence/FOUNDRY/digital/45nm/dig/lib"

# RTL File List
set RTL_FILES [list \
    "${PROJECT_ROOT}/rtl/adaptive_gating/sparsity_estimator.sv" \
    "${PROJECT_ROOT}/rtl/adaptive_gating/gating_controller.sv" \
    "${PROJECT_ROOT}/rtl/adaptive_gating/pe_adaptive.sv" \
    "${PROJECT_ROOT}/rtl/adaptive_gating/systolic16x16_adaptive.sv" \
]

# Ensure output directories exist
file mkdir $NETLIST_DIR
file mkdir $REPORT_DIR
file mkdir $LOG_DIR
file mkdir "${WORK_DIR}/xrun"

#-------------------------------------------------------------------------------
# 2. Performance: Multi-threading and Effort Controls
#-------------------------------------------------------------------------------
set_db max_cpus_per_server 8
set_db syn_generic_effort  medium
set_db syn_map_effort      medium
set_db syn_opt_effort      medium

#-------------------------------------------------------------------------------
# 3. Library Configuration
#-------------------------------------------------------------------------------
set_db init_lib_search_path $LIB_SEARCH_PATH
set_db init_hdl_search_path "${PROJECT_ROOT}/rtl/common"
set_db library $TARGET_CELL_LIB

# Enable synthesis clock-gating insertion
set_db lp_insert_clock_gating true

#-------------------------------------------------------------------------------
# 4. Read and Elaborate RTL
#-------------------------------------------------------------------------------
puts "INFO: Reading SystemVerilog RTL files..."
read_hdl -sv $RTL_FILES

puts "INFO: Elaborating design top: ${DESIGN}..."
elaborate $DESIGN

# Verification checks after elaboration
puts "INFO: Checking design integrity..."
redirect ${REPORT_DIR}/${ARCH_NAME}_design_check.rpt { check_design -unresolved }

#-------------------------------------------------------------------------------
# 5. Constraints Annotation
#-------------------------------------------------------------------------------
puts "INFO: Reading SDC timing constraints from ${SDC_FILE}..."
read_sdc $SDC_FILE

redirect ${REPORT_DIR}/${ARCH_NAME}_timing_lint.rpt { check_timing }

#-------------------------------------------------------------------------------
# 6. Switching Activity Back-Annotation (SAIF)
#-------------------------------------------------------------------------------
if {[file exists $SAIF_FILE]} {
    puts "INFO: Reading SAIF switching activity: ${SAIF_FILE}..."
    read_saif -instance $INSTANCE_PATH $SAIF_FILE
} else {
    puts "WARNING: SAIF file not found. Using vectorless power estimation."
}

#-------------------------------------------------------------------------------
# 7. Synthesis (Generic -> Map -> Optimize)
#-------------------------------------------------------------------------------
puts "INFO: \[1/3\] syn_generic - Synthesizing to generic gates..."
syn_generic

puts "INFO: \[2/3\] syn_map - Mapping to target technology cells..."
syn_map

puts "INFO: \[3/3\] syn_opt - Optimizing mapped design..."
syn_opt

#-------------------------------------------------------------------------------
# 8. Write Synthesis Outputs
#-------------------------------------------------------------------------------
puts "INFO: Writing mapped netlist and constraints..."
write_hdl > ${NETLIST_DIR}/${ARCH_NAME}_synth.v
write_sdc > ${NETLIST_DIR}/${ARCH_NAME}_synth.sdc

#-------------------------------------------------------------------------------
# 9. Report Generation
#-------------------------------------------------------------------------------
puts "INFO: Generating synthesis reports..."
report_area          > ${REPORT_DIR}/${ARCH_NAME}_area.rpt
report_timing        > ${REPORT_DIR}/${ARCH_NAME}_timing.rpt
report_power         > ${REPORT_DIR}/${ARCH_NAME}_power.rpt
report_qor           > ${REPORT_DIR}/${ARCH_NAME}_qor.rpt
report_clock_gating  > ${REPORT_DIR}/${ARCH_NAME}_clock_gating.rpt
report_summary       > ${REPORT_DIR}/${ARCH_NAME}_summary.rpt
report_messages      > ${REPORT_DIR}/${ARCH_NAME}_messages.rpt

puts "==============================================================================="
puts " SUCCESS: Genus synthesis completed for ${ARCH_NAME}"
puts " Netlist:  ${NETLIST_DIR}/${ARCH_NAME}_synth.v"
puts " Reports:  ${REPORT_DIR}/${ARCH_NAME}_*.rpt"
puts "==============================================================================="
exit
