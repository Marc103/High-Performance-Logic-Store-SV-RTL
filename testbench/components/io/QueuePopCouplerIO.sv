import constant_functions_pkg::*;

class QueuePopCouplerIO #(
    parameter DATA_WIDTH,
    parameter ADDR_WIDTH,
    parameter ASYNC,
    parameter BURSTMARK,
    parameter CONFLICT_PROOF,
    parameter REGISTERED_IN,
    parameter REGISTERED_IN_BRAM,
    parameter REGISTERED_OUT_BRAM,

    localparam QUEUE_READ_LATENCY = (ASYNC == 1)
        ? queue_async_READ_LATENCY(REGISTERED_OUT_BRAM)
        : queue_READ_LATENCY(
            CONFLICT_PROOF,
            REGISTERED_IN,
            REGISTERED_IN_BRAM,
            REGISTERED_OUT_BRAM
        ),
    localparam SPOOL_UP = queue_pop_coupler_SPOOL_UP(
        ASYNC,
        CONFLICT_PROOF,
        REGISTERED_IN,
        REGISTERED_IN_BRAM,
        REGISTERED_OUT_BRAM
    ),
    localparam SPOOL_DOWN = queue_pop_coupler_SPOOL_DOWN(),
    localparam RESERVOIR_WATERMARK_ENTRIES =
        queue_pop_coupler_RESERVOIR_WATERMARK_ENTRIES(SPOOL_UP, BURSTMARK),
    localparam RESERVOIR_BACKPRESSURE_ENTRIES =
        queue_pop_coupler_RESERVOIR_BACKPRESSURE_ENTRIES(SPOOL_UP, SPOOL_DOWN),
    localparam RESERVOIR_ENTRIES = reservoir_ENTRIES(
        RESERVOIR_WATERMARK_ENTRIES,
        RESERVOIR_BACKPRESSURE_ENTRIES
    )
);
    `QUEUE_POP_COUPLER_IO_IN_STRUCT(DATA_WIDTH)
    `QUEUE_POP_COUPLER_IO_OUT_STRUCT(DATA_WIDTH, ADDR_WIDTH)

    queue_pop_coupler_io_in_t queue_pop_coupler_io_in_q[$];
    queue_pop_coupler_io_out_t queue_pop_coupler_io_out_q[$];

    bit idle[$];
    logic unsigned [7:0] error_state[$];
    logic end_last_sequence = 0;

    function new();
    endfunction
endclass
