import constant_functions_pkg::*;

class ReservoirNoBackpressureIO #(
    parameter DATA_WIDTH,
    parameter WATERMARK_ENTRIES,
    parameter FILLMARK,
    parameter BURSTMARK,

    ////////////////////////////////////////////////////////////////
    // Globally Defined Locally Set Parameters
    localparam ENTRIES = reservoir_ENTRIES(WATERMARK_ENTRIES, 0),
    localparam LATENCY = 1
);

    `RESERVOIR_NO_BACKPRESSURE_IO_IN_STRUCT(DATA_WIDTH)
    `RESERVOIR_NO_BACKPRESSURE_IO_OUT_STRUCT(DATA_WIDTH)

    reservoir_no_backpressure_io_in_t reservoir_no_backpressure_io_in_q[$];
    reservoir_no_backpressure_io_out_t reservoir_no_backpressure_io_out_q[$];

    // Sequencing Info
    bit idle [$];
    logic unsigned [7:0] error_state[$];
    logic end_last_sequence = 0;

    function new ();
    endfunction

endclass
