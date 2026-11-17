# The driver prepends the FFT_* values from config.tcl to a standalone copy of
# this file. Explicit units keep clock periods in ns rather than ps.
set_units -time ns -capacitance fF

create_clock -name core_clk -period $FFT_CLOCK_PERIOD_NS \
    -waveform [list 0.0 [expr {$FFT_CLOCK_PERIOD_NS / 2.0}]] [get_ports clk_i]
set_clock_transition $FFT_CLOCK_TRANSITION_NS [get_clocks core_clk]
set_clock_uncertainty -setup $FFT_SETUP_UNCERTAINTY_NS [get_clocks core_clk]
set_clock_uncertainty -hold $FFT_HOLD_UNCERTAINTY_NS [get_clocks core_clk]

# All external inputs, including synchronous rst_i and runtime controls, are
# clocked interface signals. Constrain BOTH min and max boundary delays.
set fft_data_inputs [remove_from_collection [all_inputs] [get_ports clk_i]]
set_input_delay -clock core_clk -max $FFT_INPUT_DELAY_MAX_NS $fft_data_inputs
set_input_delay -clock core_clk -min $FFT_INPUT_DELAY_MIN_NS $fft_data_inputs
set_input_transition $FFT_INPUT_TRANSITION_NS $fft_data_inputs
set_output_delay -clock core_clk -max $FFT_OUTPUT_DELAY_MAX_NS [all_outputs]
set_output_delay -clock core_clk -min $FFT_OUTPUT_DELAY_MIN_NS [all_outputs]
set_load $FFT_OUTPUT_LOAD_FF [all_outputs]
set_max_transition $FFT_MAX_TRANSITION_NS [current_design]

# rst_i is synchronous and also gates enables combinationally: keep it timed.
# Do not tie reset/configuration/go to constants, false-path the memory ports,
# or apply II_CYCLES as a multicycle exception. Internal pipelines advance on
# every clock. No generated clocks or clock gating are requested by this flow.
