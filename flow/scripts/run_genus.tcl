#===============================================================================
# Cadence Genus Synthesis Script
# Target: HSA16 Systolic Accelerator (Adaptive Gating Top)
# Foundry Library: 45nm typical standard cell library
#===============================================================================

#-------------------------------------------------------------------------------
# 1. Parameter and Path Setup
#-------------------------------------------------------------------------------
set DESIGN            "systolic16x16_adaptive"

# Automatically detect project root directory based on current working directory
if {[file exists "flow"]} {
    set PROJECT_ROOT [pwd]
} elseif {[file exists "../flow"]} {
    set PROJECT_ROOT [file normalize "[pwd]/.."]
} else {
    set PROJECT_ROOT [pwd]
    puts "WARNING: Project root auto-detection failed. Using current directory: ${PROJECT_ROOT}"
}

set WORK_DIR          "${PROJECT_ROOT}/flow"
set NETLIST_DIR       "${WORK_DIR}/netlists"
set REPORT_DIR        "${WORK_DIR}/reports/genus"
set LOG_DIR           "${WORK_DIR}/logs"
set SDC_FILE          "${WORK_DIR}/constraints/systolic16x16.sdc"

# Foundry 45nm typical library path
set TARGET_CELL_LIB   "/home/Cadence/FOUNDRY/digital/45nm/dig/lib/typical.lib"

# RTL File List (dependencies first, with full paths relative to PROJECT_ROOT)
set RTL_FILES [list \
    "${PROJECT_ROOT}/rtl/common/hsa_params.svh" \
    "${PROJECT_ROOT}/rtl/adaptive_gating/sparsity_estimator.sv" \
    "${PROJECT_ROOT}/rtl/adaptive_gating/gating_controller.sv" \
    "${PROJECT_ROOT}/rtl/adaptive_gating/pe_adaptive.sv" \
    "${PROJECT_ROOT}/rtl/adaptive_gating/systolic16x16_adaptive.sv" \
]

# Ensure output directories exist
file mkdir $NETLIST_DIR
file mkdir $REPORT_DIR
file mkdir $LOG_DIR

#-------------------------------------------------------------------------------
# 2. Library Configuration
#-------------------------------------------------------------------------------
# Set db libraries (Common UI format used in newer Genus versions)
set_db library $TARGET_CELL_LIB
set_db target_library $TARGET_CELL_LIB
set_db link_library $TARGET_CELL_LIB

# Legacy/Attribute-style backup configuration (in case legacy UI is running)
set_attribute library $TARGET_CELL_LIB
set_attribute target_library $TARGET_CELL_LIB
set_attribute link_library $TARGET_CELL_LIB

#-------------------------------------------------------------------------------
# 3. Read and Elaborate RTL
#-------------------------------------------------------------------------------
puts "INFO: Reading SystemVerilog RTL files..."
read_hdl -sv $RTL_FILES

puts "INFO: Elaborating design top: ${DESIGN}..."
elaborate $DESIGN

# Check for design errors/warnings after elaboration
check_design -unresolved

#-------------------------------------------------------------------------------
# 4. Constraints Annotation
#-------------------------------------------------------------------------------
if {[file exists $SDC_FILE]} {
    puts "INFO: Reading SDC timing constraints from ${SDC_FILE}..."
    read_sdc $SDC_FILE
} else {
    error "ERROR: Constraints file ${SDC_FILE} not found. Timing cannot be verified!"
}

# Verify constraints are loaded correctly
report timing -lint

#-------------------------------------------------------------------------------
# 5. Switching Activity Back-Annotation (SAIF)
#-------------------------------------------------------------------------------
set SAIF_FILE "${WORK_DIR}/xrun/adaptive.saif"
set INSTANCE_PATH "tb_b16_adaptive/dut"

if {[file exists $SAIF_FILE]} {
    puts "INFO: Reading dynamic switching activity from SAIF file: ${SAIF_FILE}..."
    # Read the SAIF file and map it to the DUT instance in the testbench
    read_saif -instance $INSTANCE_PATH $SAIF_FILE
} else {
    puts "WARNING: SAIF file ${SAIF_FILE} not found. Genus will default to vectorless estimation."
    puts "WARNING: Run dynamic simulations first to dump VCD and convert to SAIF using vcd2saif."
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
write_hdl > ${NETLIST_DIR}/${DESIGN}_synth.v
write_sdc > ${NETLIST_DIR}/${DESIGN}_synth.sdc
write_sdf > ${NETLIST_DIR}/${DESIGN}_synth.sdf

#-------------------------------------------------------------------------------
# 8. Report Generation
#-------------------------------------------------------------------------------
puts "INFO: Generating synthesis reports..."
report_area   > ${REPORT_DIR}/${DESIGN}_area.rpt
report_timing > ${REPORT_DIR}/${DESIGN}_timing.rpt
report_power  > ${REPORT_DIR}/${DESIGN}_power.rpt
report_qor    > ${REPORT_DIR}/${DESIGN}_qor.rpt
report_gates  > ${REPORT_DIR}/${DESIGN}_gates.rpt

puts "SUCCESS: Genus synthesis flow completed for ${DESIGN}."
exit
