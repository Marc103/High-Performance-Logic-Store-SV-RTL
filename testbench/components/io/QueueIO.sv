/*
 * Queue IO Class
 */
import constant_functions_pkg::*;

class QueueIO #(
    parameter ADDR_WIDTH,
    parameter DATA_WIDTH,
    parameter CONFLICT_PROOF,       // [0, 1]
    parameter REGISTERED_IN,        // [0, 1]
    parameter REGISTERED_IN_BRAM,   // [0, 1]
    parameter REGISTERED_OUT_BRAM,  // [0, 1]
    parameter NUMBER_OF_QUEUES,     // [1,..]

    ////////////////////////////////////////////////////////////////
    // Globally Defined Locally Set Parameters
    localparam DATA_DEPTH        = queue_DATA_DEPTH                  (ADDR_WIDTH),
    localparam READ_LATENCY      = queue_READ_LATENCY                (CONFLICT_PROOF, REGISTERED_IN, REGISTERED_IN_BRAM, REGISTERED_OUT_BRAM),
    localparam WRITE_LATENCY     = queue_WRITE_LATENCY               (CONFLICT_PROOF, REGISTERED_IN, REGISTERED_IN_BRAM),
    localparam READ_LATENCY_BRAM = bram_dual_port_simple_READ_LATENCY(REGISTERED_IN_BRAM, REGISTERED_OUT_BRAM)
);
    `QUEUE_IO_IN_STRUCT(NUMBER_OF_QUEUES, DATA_WIDTH, ADDR_WIDTH) 
    `QUEUE_IO_OUT_STRUCT(NUMBER_OF_QUEUES, DATA_WIDTH, ADDR_WIDTH)

    queue_io_in_t queue_io_in_q[$];
    queue_io_out_t queue_io_out_q[$];

    // Sequencing Info
    bit ignore [$];
    logic unsigned [7:0] error_state[$];
    logic end_last_sequence = 0;

    function new ();
    endfunction
endclass