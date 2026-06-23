#===============================================================================
# Cadence Genus Synthesis Script - PE Gating Architecture
# Target: HSA16 Systolic Accelerator
#===============================================================================

#-------------------------------------------------------------------------------
# 1. Parameter and Path Setup
#-------------------------------------------------------------------------------
set ARCH_NAME         "pe_gating"
set DESIGN            "systolic16x16_pe_gated"

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
set INSTANCE_PATH     "tb_b16_pe_gated/dut"

# Foundry 45nm typical library path
set TARGET_CELL_LIB   "typical.lib"
set LIB_SEARCH_PATH   "/home/Cadence/FOUNDRY/digital/45nm/dig/lib"

# RTL File List
set RTL_FILES [list \
    "${PROJECT_ROOT}/rtl/common/hsa_params.svh" \
    "${PROJECT_ROOT}/rtl/pe_gating/pe_gated.sv" \
    "${PROJECT_ROOT}/rtl/pe_gating/systolic16x16_pe_gated.sv" \
]

# Ensure output directories exist
file mkdir $NETLIST_DIR
file mkdir $REPORT_DIR
file mkdir $LOG_DIR
file mkdir "${WORK_DIR}/xrun"

#-------------------------------------------------------------------------------
# 2. Library and Power Configuration
#-------------------------------------------------------------------------------
# Set library search path first to help Genus locate typical.lib
set_db init_lib_search_path $LIB_SEARCH_PATH

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

# Verification checks after elaboration using safe Tcl redirect
puts "INFO: Checking design integrity..."
redirect ${REPORT_DIR}/${ARCH_NAME}_design_check.rpt { check_design -unresolved }
redirect ${REPORT_DIR}/${ARCH_NAME}_design_rules.rpt { report_design_rules }

#-------------------------------------------------------------------------------
# 4. Constraints Annotation
#-------------------------------------------------------------------------------
puts "INFO: Reading static SDC timing constraints from ${SDC_FILE}..."
read_sdc $SDC_FILE

# Output timing lint reports to a report file using safe check_timing
redirect ${REPORT_DIR}/${ARCH_NAME}_timing_lint.rpt { check_timing }

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
# 7. Write Synthesis Outputs (No SDF generated prior to Innovus)
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
