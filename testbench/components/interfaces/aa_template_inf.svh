`ifndef ???_INF 
    `define ???_INF
interface ???_inf #(
    parameter DATA_WIDTH,
    parameter FANOUT_SIZE,
    parameter FANOUT_FACTOR,
    parameter IMMEDIATE_START_FANOUT,

    ////////////////////////////////////////////////////////////////
    // Globally Defined Locally Set Parameters
    localparam STAGES            = ???_STAGES           (FANOUT_FACTOR, FANOUT_SIZE),
    localparam FINAL_FANOUT_SIZE = ???_FINAL_FANOUT_SIZE(FANOUT_FACTOR, STAGES),
    localparam LATENCY           = ???_LATENCY          (IMMEDIATE_START_FANOUT, STAGES)
) (
    ???
);
    ???
    // testbench sequencing signals
    logic start_sequence;
    logic end_sequence;
    logic end_last_sequence;
    logic idle;
endinterface
`endif 