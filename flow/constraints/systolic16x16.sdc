#===============================================================================
# Design Constraints (SDC) for HSA16 Systolic Array
# Target Frequency: 500 MHz (Clock Period: 2.0 ns)
#===============================================================================

# Define Clock
create_clock -name clk -period 2.0 [get_ports clk]

# Clock Uncertainty and Transition for timing analysis
set_clock_uncertainty 0.100 [get_clocks clk]
set_clock_transition  0.050 [get_clocks clk]

# Input / Output Delays (assume 20% of clock cycle for external delay)
set_input_delay  -clock clk -max 0.400 [remove_from_collection [all_inputs] [get_ports clk]]
set_input_delay  -clock clk -min 0.080 [remove_from_collection [all_inputs] [get_ports clk]]

set_output_delay -clock clk -max 0.400 [all_outputs]
set_output_delay -clock clk -min 0.080 [all_outputs]

# Set Max Fanout Constraint
set_max_fanout 16 [current_design]

# Set Max Transition and Capacitance Constraints for routing/buffering quality
set_max_transition 0.10 [current_design]
set_max_capacitance 0.05 [current_design]

# Set Output Load (typical standard load pin capacitance)
set_load 0.010 [all_outputs]
