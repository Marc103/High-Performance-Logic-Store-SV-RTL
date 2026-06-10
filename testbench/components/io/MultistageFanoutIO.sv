/*
 * Multistage Fanout Class
 */
import constant_functions_pkg::*;

class MultistageFanoutIO #(
    parameter DATA_WIDTH,
    parameter FANOUT_SIZE,
    parameter FANOUT_FACTOR,
    parameter IMMEDIATE_START_FANOUT = 0,

    ////////////////////////////////////////////////////////////////
    // Globally Defined Locally Set Parameters
    localparam STAGES            = multistage_fanout_STAGES           (FANOUT_FACTOR, FANOUT_SIZE),
    localparam FINAL_FANOUT_SIZE = multistage_fanout_FINAL_FANOUT_SIZE(FANOUT_FACTOR, STAGES),
    localparam LATENCY           = multistage_fanout_LATENCY          (IMMEDIATE_START_FANOUT, STAGES)
);
    `MULTISTAGE_FANOUT_IO_IN_STRUCT(DATA_WIDTH)
    `MULTISTAGE_FANOUT_IO_OUT_STRUCT(DATA_WIDTH, FINAL_FANOUT_SIZE)

    logic [DATA_WIDTH - 1 : 0] data_i;

    logic [FINAL_FANOUT_SIZE - 1 : 0][DATA_WIDTH - 1 : 0] data_o;

    multistage_fanout_io_in_t multistage_fanout_io_in_q[$];
    multistage_fanout_io_out_t multistage_fanout_io_out_q[$];

    // Sequencing Info
    bit idle [$];
    logic unsigned [7:0] error_state[$];
    logic end_last_sequence = 0;

    function new ();
    endfunction
endclass