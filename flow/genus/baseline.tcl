#===============================================================================
# Cadence Genus Synthesis Script - Baseline Architecture
# Target: HSA16 Systolic Accelerator
#===============================================================================

#-------------------------------------------------------------------------------
# 1. Parameter and Path Setup
#-------------------------------------------------------------------------------
set ARCH_NAME         "baseline"
set DESIGN            "systolic16x16_baseline"

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
set SAIF_FILE         "${WORK_DIR}/saif/${ARCH_NAME}.saif"
set INSTANCE_PATH     "tb_b16/dut"

# Foundry 45nm typical library path
set TARGET_CELL_LIB   "/home/Cadence/FOUNDRY/digital/45nm/dig/lib/typical.lib"

# RTL File List
set RTL_FILES [list \
    "${PROJECT_ROOT}/rtl/common/hsa_params.svh" \
    "${PROJECT_ROOT}/rtl/baseline/pe_baseline.sv" \
    "${PROJECT_ROOT}/rtl/baseline/systolic16x16_baseline.sv" \
]

# Ensure output directories exist
file mkdir $NETLIST_DIR
file mkdir $REPORT_DIR
file mkdir $LOG_DIR

#-------------------------------------------------------------------------------
# 2. Library and Power Configuration
#-------------------------------------------------------------------------------
set_db library $TARGET_CELL_LIB
set_db target_library $TARGET_CELL_LIB
set_db link_library $TARGET_CELL_LIB

# Enable synthesis clock-gating insertion
set_db lp_insert_clock_gating true

#-------------------------------------------------------------------------------
# 3. Read and Elaborate RTL
#-------------------------------------------------------------------------------
puts "INFO: Reading SystemVerilog RTL files..."
read_hdl -sv $RTL_FILES

puts "INFO: Elaborating design top: ${DESIGN}..."
elaborate $DESIGN

# Verification checks after elaboration
puts "INFO: Checking design integrity..."
check_design -unresolved > ${REPORT_DIR}/${ARCH_NAME}_design_check.rpt
report_design_rules > ${REPORT_DIR}/${ARCH_NAME}_design_rules.rpt

#-------------------------------------------------------------------------------
# 4. Constraints Annotation
#-------------------------------------------------------------------------------
puts "INFO: Reading static SDC timing constraints from ${SDC_FILE}..."
read_sdc $SDC_FILE

# Output timing lint reports to a report file
report timing -lint > ${REPORT_DIR}/${ARCH_NAME}_timing_lint.rpt

#-------------------------------------------------------------------------------
# 5. Switching Activity Back-Annotation (SAIF)
#-------------------------------------------------------------------------------
if {[file exists $SAIF_FILE]} {
    puts "INFO: Reading dynamic switching activity from SAIF file: ${SAIF_FILE}..."
    read_saif -instance $INSTANCE_PATH $SAIF_FILE
} else {
    puts "WARNING: SAIF file ${SAIF_FILE} not found. Defaulting to vectorless estimation."
}

#-------------------------------------------------------------------------------
# 6. Synthesis and Mapping
#-------------------------------------------------------------------------------
puts "INFO: Synthesizing design to generic gates..."
synthesize -to_generic

puts "INFO: Mapping and optimizing to target foundry cells..."
synthesize -to_mapped

#-------------------------------------------------------------------------------
# 7. Write Synthesis Outputs
#-------------------------------------------------------------------------------
puts "INFO: Writing mapped netlist and gate-level constraints..."
write_hdl > ${NETLIST_DIR}/${ARCH_NAME}_synth.v
write_sdc > ${NETLIST_DIR}/${ARCH_NAME}_synth.sdc

#-------------------------------------------------------------------------------
# 8. Report Generation
#-------------------------------------------------------------------------------
puts "INFO: Generating synthesis reports..."
report_area         > ${REPORT_DIR}/${ARCH_NAME}_area.rpt
report_timing       > ${REPORT_DIR}/${ARCH_NAME}_timing.rpt
report_power        > ${REPORT_DIR}/${ARCH_NAME}_power.rpt
report_qor          > ${REPORT_DIR}/${ARCH_NAME}_qor.rpt
report_gates        > ${REPORT_DIR}/${ARCH_NAME}_gates.rpt
report_clock_gating > ${REPORT_DIR}/${ARCH_NAME}_clock_gating.rpt

puts "SUCCESS: Genus synthesis flow completed for ${ARCH_NAME}."
exit
