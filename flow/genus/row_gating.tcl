#===============================================================================
# Cadence Genus Synthesis Script - Row Gating Architecture
# Target: HSA16 Systolic Accelerator
#===============================================================================

#-------------------------------------------------------------------------------
# 1. Parameter and Path Setup
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

# Determine clock period from environment variable for sweeps (default: 2.0 ns)
if {[info exists env(CLK_PERIOD)]} {
    set CLK_PERIOD $env(CLK_PERIOD)
    set CLK_SUFFIX "_${CLK_PERIOD}ns"
    puts "INFO: Environment variable CLK_PERIOD detected. Setting target period to: ${CLK_PERIOD} ns..."
} else {
    set CLK_PERIOD 2.0
    set CLK_SUFFIX ""
    puts "INFO: Using baseline clock period of 2.0 ns (500 MHz)."
}

set WORK_DIR          "${PROJECT_ROOT}/flow"
set NETLIST_DIR       "${WORK_DIR}/netlists"
set REPORT_DIR        "${WORK_DIR}/reports/genus"
set LOG_DIR           "${WORK_DIR}/logs"
set SDC_FILE          "${WORK_DIR}/constraints/systolic16x16.sdc"
set SAIF_FILE         "${WORK_DIR}/saif/${ARCH_NAME}.saif"
set INSTANCE_PATH     "tb_b16_row_gated/dut"

# Foundry 45nm typical library path
set TARGET_CELL_LIB   "/home/Cadence/FOUNDRY/digital/45nm/dig/lib/typical.lib"

# RTL File List
set RTL_FILES [list \
    "${PROJECT_ROOT}/rtl/common/hsa_params.svh" \
    "${PROJECT_ROOT}/rtl/row_gating/pe_row_gated.sv" \
    "${PROJECT_ROOT}/rtl/row_gating/systolic16x16_row_gated.sv" \
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
set_attribute lp_insert_clock_gating true

#-------------------------------------------------------------------------------
# 3. Read and Elaborate RTL
#-------------------------------------------------------------------------------
puts "INFO: Reading SystemVerilog RTL files..."
read_hdl -sv $RTL_FILES

puts "INFO: Elaborating design top: ${DESIGN}..."
elaborate $DESIGN

# Verification checks after elaboration
puts "INFO: Checking design integrity..."
check_design -unresolved
report_design_rules > ${REPORT_DIR}/${ARCH_NAME}_design_rules${CLK_SUFFIX}.rpt

#-------------------------------------------------------------------------------
# 4. Constraints Annotation
#-------------------------------------------------------------------------------
if {[info exists env(CLK_PERIOD)]} {
    puts "INFO: Generating dynamic timing constraints for clock period: ${CLK_PERIOD} ns..."
    create_clock -name clk -period $CLK_PERIOD [get_ports clk]
    set_clock_uncertainty 0.100 [get_clocks clk]
    set_clock_transition  0.050 [get_clocks clk]
    
    set_input_delay  -clock clk -max [expr 0.20 * $CLK_PERIOD] [remove_from_collection [all_inputs] [get_ports clk]]
    set_input_delay  -clock clk -min [expr 0.04 * $CLK_PERIOD] [remove_from_collection [all_inputs] [get_ports clk]]
    
    set_output_delay -clock clk -max [expr 0.20 * $CLK_PERIOD] [all_outputs]
    set_output_delay -clock clk -min [expr 0.04 * $CLK_PERIOD] [all_outputs]
    
    set_max_fanout 16 [current_design]
    set_max_transition 0.10 [current_design]
    set_max_capacitance 0.05 [current_design]
    set_load 0.010 [all_outputs]
} else {
    puts "INFO: Reading static SDC timing constraints from ${SDC_FILE}..."
    read_sdc $SDC_FILE
}
report timing -lint

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
write_hdl > ${NETLIST_DIR}/${ARCH_NAME}_synth${CLK_SUFFIX}.v
write_sdc > ${NETLIST_DIR}/${ARCH_NAME}_synth${CLK_SUFFIX}.sdc
write_sdf > ${NETLIST_DIR}/${ARCH_NAME}_synth${CLK_SUFFIX}.sdf

#-------------------------------------------------------------------------------
# 8. Report Generation
#-------------------------------------------------------------------------------
puts "INFO: Generating synthesis reports..."
report_area         > ${REPORT_DIR}/${ARCH_NAME}_area${CLK_SUFFIX}.rpt
report_timing       > ${REPORT_DIR}/${ARCH_NAME}_timing${CLK_SUFFIX}.rpt
report_power        > ${REPORT_DIR}/${ARCH_NAME}_power${CLK_SUFFIX}.rpt
report_qor          > ${REPORT_DIR}/${ARCH_NAME}_qor${CLK_SUFFIX}.rpt
report_gates        > ${REPORT_DIR}/${ARCH_NAME}_gates${CLK_SUFFIX}.rpt
report_clock_gating > ${REPORT_DIR}/${ARCH_NAME}_clock_gating${CLK_SUFFIX}.rpt

puts "SUCCESS: Genus synthesis flow completed for ${ARCH_NAME}${CLK_SUFFIX}."
exit
