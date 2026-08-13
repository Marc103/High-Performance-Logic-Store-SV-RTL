import constant_functions_pkg::*;

class QueueTrainIO #(
    parameter DATA_WIDTH,
    parameter ADDR_WIDTH,
    parameter NUMBER_OF_CARRIAGES,
    parameter FRONT_ASYNC,
    parameter END_ASYNC,
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
    localparam TOTAL_DATA_DEPTH = NUMBER_OF_CARRIAGES * DATA_DEPTH,
    localparam FRONT_CARRIAGE_ASYNC =
        (FRONT_ASYNC == 1) ||
        ((NUMBER_OF_CARRIAGES == 1) && (END_ASYNC == 1))
);

    `QUEUE_TRAIN_IO_IN_STRUCT(DATA_WIDTH)
    `QUEUE_TRAIN_IO_OUT_STRUCT(DATA_WIDTH)

    queue_train_io_in_t queue_train_io_in_q[$];
    queue_train_io_out_t queue_train_io_out_q[$];

    // Sequencing Info
    bit idle [$];
    logic unsigned [7:0] error_state[$];
    logic end_last_sequence = 0;

    function new();
    endfunction
endclass
