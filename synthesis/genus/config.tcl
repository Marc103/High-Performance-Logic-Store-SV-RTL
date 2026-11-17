# Genus Stylus/Common UI configuration for the external-memory FFT accelerator.
# All time values below are ns, all capacitances are fF.
# Optional overrides: source a Tcl file via the FFT_GENUS_CONFIG environment
# variable. It may change entries in ::fft_syn::cfg and ::fft_syn::parameters.
namespace eval ::fft_syn {
    variable script_dir [file dirname [file normalize [info script]]]
    variable repo_root [file normalize [file join $script_dir ../..]]
    variable cfg
    array set cfg [list \
        library_root [file join $script_dir libraries NangateOpenCellLibrary] \
        output_dir [file join $script_dir runs abfp32_300mhz] \
        clock_period_ns [expr {1000.0 / 300.0}] \
        clock_transition_ns 0.05 \
        setup_uncertainty_ns 0.10 \
        hold_uncertainty_ns 0.05 \
        input_delay_max_ns 0.30 \
        input_delay_min_ns 0.05 \
        output_delay_max_ns 0.30 \
        output_delay_min_ns -0.05 \
        input_transition_ns 0.05 \
        output_load_ff 5.0 \
        max_transition_ns 0.20 \
        effort high]

    # Match the tested ABFP32 scaffold: radix 16, 6 exponent bits, 25 explicit
    # mantissa bits, 32768 complex sample addresses and 16384 twiddle addresses.
    # Use the RTL's minimum launch interval. In-place stage dependencies still
    # depend on FFT size and memory latency; II is NOT a timing multicycle.
    variable parameters
    array set parameters {
        BASE 16
        EXPONENT_WIDTH 6
        MANTISSA_WIDTH 25
        SAMPLES_ADDR_WIDTH 15
        TWIDDLES_ADDR_WIDTH 14
        II_CYCLES 4
        READ_LATENCY 1
        WRITE_LATENCY 1
        RESET_PIPELINE_DEPTH 1
        LUTX 6
        GRADE 1
        REGSITERED_MULTIPLIER 1
        REGISTERED_NORMALIZE 1
        REGISTERED_SWAP_IN 1
        REGISTERED_SWAP_MUX 1
        REGISTERED_ALIGN_STICKY_IN 1
        REGISTERED_ALIGN_EXPONENT_MUX 1
        REGISTERED_ALIGN_MUX 1
        REGISTERED_ADD_CONVERT 1
        REGISTERED_ADD_CONVERT_CONVERT 1
        REGISTERED_PRIORITY_ENCODE 1
        REGISTERED_PRIORITY_ENCODE_ENCODER 1
        REGISTERED_NORMALIZE_ROUND_POST_NORMALIZE 1
        REGISTERED_NORMALIZE_ROUND_POST_NORMALIZE_ROUND 1
    }

    # Voltage/temperature copied from the actual NLDM headers. The process
    # scalar is 1.0 in ALL five files: the cells already contain each corner's
    # characterized tables; process labels must not be turned into scale factors.
    variable corners {
        slow      {0.95 125.0}
        worst_low {0.95 -40.0}
        typical   {1.10 25.0}
        fast      {1.25 0.0}
        low_temp  {1.25 -40.0}
    }

    # Compile only this DUT's transitive dependency set, package first.
    # No testbench classes, memories, or out_of_context.sv wrapper are read.
    variable relative_sources {
        rtl/rtl_utilities_pkg.sv
        rtl/io_circuits/pipe/pipe.sv
        rtl/processing_elements/reduction_tree/reduction_tree.sv
        rtl/processing_elements/max/max.sv
        rtl/processing_elements/multistage_mux/multistage_mux.sv
        rtl/processing_elements/priority_encoder/priority_encoder.sv
        rtl/processing_elements/alternate_base_fp_adder/alternate_base_fp_adder.sv
        rtl/processing_elements/alternate_base_fp_multiplier/alternate_base_fp_multiplier.sv
        rtl/processing_elements/fft_multiplier_core/fft_multiplier_core.sv
        rtl/processing_elements/fft_adder_core/fft_adder_core.sv
        rtl/fsm/fsm_fft_reader/fsm_fft_reader.sv
        rtl/fsm/fsm_fft_writer/fsm_fft_writer.sv
        rtl/processing_elements/fft_accelerator/fft_accelerator.sv
    }
}

if {[info exists ::env(NANGATE_ROOT)] && $::env(NANGATE_ROOT) ne ""} {
    set ::fft_syn::cfg(library_root) [file normalize $::env(NANGATE_ROOT)]
}
if {[info exists ::env(FFT_GENUS_OUT)] && $::env(FFT_GENUS_OUT) ne ""} {
    set ::fft_syn::cfg(output_dir) [file normalize $::env(FFT_GENUS_OUT)]
}
if {[info exists ::env(FFT_GENUS_CONFIG)] && $::env(FFT_GENUS_CONFIG) ne ""} {
    source [file normalize $::env(FFT_GENUS_CONFIG)]
}
