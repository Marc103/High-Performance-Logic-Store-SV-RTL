import constant_functions_pkg::*;

class ReservoirIO #(
    parameter DATA_WIDTH,
    parameter WATERMARK_ENTRIES,
    parameter BACKPRESSURE_ENTRIES,
    parameter BURSTMARK,

    ////////////////////////////////////////////////////////////////
    // Globally Defined Locally Set Parameters
    localparam ENTRIES = reservoir_ENTRIES(WATERMARK_ENTRIES, BACKPRESSURE_ENTRIES),
    localparam LATENCY = 1
);

    `RESERVOIR_IO_IN_STRUCT(DATA_WIDTH)
    `RESERVOIR_IO_OUT_STRUCT(DATA_WIDTH)

    reservoir_io_in_t reservoir_io_in_q[$];
    reservoir_io_out_t reservoir_io_out_q[$];

    // Sequencing Info
    bit idle [$];
    logic unsigned [7:0] error_state[$];
    logic end_last_sequence = 0;

    function new ();
    endfunction

endclass
