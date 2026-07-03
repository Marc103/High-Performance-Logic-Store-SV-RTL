import constant_functions_pkg::*;

class MultistageMuxIO #(
    parameter DATA_WIDTH,
    parameter SIZE,
    parameter REGISTERED_IN,
    parameter LUTX,
    parameter GRADE,

    ////////////////////////////////////////////////////////////////
    // Globally Defined Locally Set Parameters

    localparam SELECTOR_WIDTH       = multistage_mux_SELECTOR_WIDTH(SIZE),
    localparam GROUP_SELECTOR_WIDTH = multistage_mux_GROUP_SELECTOR_WIDTH(LUTX, GRADE),
    localparam GROUP_SIZE           = multistage_mux_GROUP_SIZE(GROUP_SELECTOR_WIDTH),
    localparam STAGES               = multistage_mux_STAGES(GROUP_SIZE, SIZE),
    localparam LATENCY              = multistage_mux_LATENCY(REGISTERED_IN, STAGES)
);

    `MULTISTAGE_MUX_IO_IN_STRUCT(DATA_WIDTH, SIZE, SELECTOR_WIDTH)
    `MULTISTAGE_MUX_IO_OUT_STRUCT(DATA_WIDTH)

    multistage_mux_io_in_t multistage_mux_io_in_q[$];
    multistage_mux_io_out_t multistage_mux_io_out_q[$];

    // Sequencing Info
    bit idle [$];
    logic unsigned [7:0] error_state[$];
    logic end_last_sequence = 0;

    function new ();
    endfunction

endclass
