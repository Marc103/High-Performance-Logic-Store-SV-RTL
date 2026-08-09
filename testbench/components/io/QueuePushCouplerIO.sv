import constant_functions_pkg::*;

class QueuePushCouplerIO #(
    parameter DATA_WIDTH,
    parameter SIMPLE,
    parameter ASYNC,
    parameter BURST_SIZE,
    parameter ADDR_WIDTH,

    ////////////////////////////////////////////////////////////////
    // Globally Defined Locally Set Parameters
    localparam DATA_DEPTH = queue_DATA_DEPTH(ADDR_WIDTH),
    localparam RESERVOIR_ENTRIES = BURST_SIZE + 2,
    localparam LATENCY = (SIMPLE == 1) ? 0 : 1
);

    `QUEUE_PUSH_COUPLER_IO_IN_STRUCT(DATA_WIDTH)
    `QUEUE_PUSH_COUPLER_IO_OUT_STRUCT(DATA_WIDTH, ADDR_WIDTH)

    queue_push_coupler_io_in_t queue_push_coupler_io_in_q[$];
    queue_push_coupler_io_out_t queue_push_coupler_io_out_q[$];

    // Sequencing Info
    bit idle [$];
    logic unsigned [7:0] error_state[$];
    logic end_last_sequence = 0;

    function new ();
    endfunction

endclass
