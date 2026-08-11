import constant_functions_pkg::*;

class QueueCarriageIO #(
    parameter DATA_WIDTH,
    parameter ADDR_WIDTH,
    parameter ASYNC,
    parameter PUSH_SIMPLE,
    parameter PUSH_BURST_SIZE,
    parameter POP_BURSTMARK,
    parameter CONFLICT_PROOF,
    parameter REGISTERED_IN,
    parameter REGISTERED_IN_BRAM,
    parameter REGISTERED_OUT_BRAM,
    parameter SYNC_STAGES,

    ////////////////////////////////////////////////////////////////
    // Globally Defined Locally Set Parameters
    localparam DATA_DEPTH = queue_DATA_DEPTH(ADDR_WIDTH),
    localparam QUEUE_READ_LATENCY = queue_carriage_READ_LATENCY(
        ASYNC,
        CONFLICT_PROOF,
        REGISTERED_IN,
        REGISTERED_IN_BRAM,
        REGISTERED_OUT_BRAM
    )
);
    `QUEUE_CARRIAGE_IO_IN_STRUCT(DATA_WIDTH)
    `QUEUE_CARRIAGE_IO_OUT_STRUCT(DATA_WIDTH)

    queue_carriage_io_in_t queue_carriage_io_in_q[$];
    queue_carriage_io_out_t queue_carriage_io_out_q[$];

    bit idle[$];
    logic unsigned [7:0] error_state[$];
    logic end_last_sequence = 0;

    function new();
    endfunction
endclass
