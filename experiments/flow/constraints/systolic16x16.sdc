#===============================================================================
# Design Constraints (SDC) for HSA16 Systolic Array
# Target Frequency: 500 MHz (Clock Period: 2.0 ns)
#===============================================================================

# Define Clock
create_clock -name clk -period 2.0 [get_ports clk]

# Clock Uncertainty and Transition
set_clock_uncertainty 0.10 [get_clocks clk]
set_clock_transition 0.05 [get_clocks clk]

# Input / Output Delays
set_input_delay 0.40 -clock clk [remove_from_collection [all_inputs] [get_ports clk]]
set_output_delay 0.40 -clock clk [all_outputs]

# Design Rule Constraints
set_max_fanout 16 [current_design]
set_max_transition 0.10 [current_design]
set_max_capacitance 0.05 [current_design]

# Output Load Constraint
set_load 0.01 [all_outputs]
