/*
 * Multistage Fanout Class
 */
import constant_functions_pkg::*;

class MultistageFanoutClass #(
    parameter DATA_WIDTH,
    parameter FANOUT_SIZE,
    parameter FANOUT_FACTOR,
    parameter IMMEDIATE_START_FANOUT = 0,

    ////////////////////////////////////////////////////////////////
    // Globally Defined Locally Set Parameters
    localparam STAGES            = multistage_fanout_STAGES           (FANOUT_FACTOR, FANOUT_SIZE),
    localparam PRE_FANOUT_SIZE   = multistage_fanout_PRE_FANOUT_SIZE  (FANOUT_FACTOR, STAGES),
    localparam FINAL_FANOUT_SIZE = multistage_fanout_FINAL_FANOUT_SIZE(FANOUT_FACTOR, STAGES),
    localparam LATENCY           = multistage_fanout_LATENCY          (IMMEDIATE_START_FANOUT, STAGES)
);
    logic [DATA_WIDTH - 1 : 0] data_i;

    logic [FINAL_FANOUT_SIZE][DATA_WIDTH - 1 : 0] data_o;

    int data_width, fanout_size, fanout_factor, immediate_start_fanout, 
        stages, pre_fanout_size, final_fanout_size;


    function new ();
        this.data_width             = DATA_WIDTH;
        this.fanout_size            = FANOUT_SIZE;
        this.fanout_factor          = FANOUT_FACTOR;
        this.immediate_start_fanout = IMMEDIATE_START_FANOUT;
        this.stages                 = STAGES;
        this.pre_fanout_size        = PRE_FANOUT_SIZE;
        this.final_fanout_size      = FINAL_FANOUT_SIZE;
    endfunction
endclass