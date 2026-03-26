`ifndef MULTISTAGE_FANOUT_INF 
    `define MULTISTAGE_FANOUT_INF
interface multistage_fanout_inf #(
    parameter DATA_WIDTH,
    parameter FANOUT_SIZE,
    parameter FANOUT_FACTOR,
    parameter IMMEDIATE_START_FANOUT,

    ////////////////////////////////////////////////////////////////
    // Globally Defined Locally Set Parameters
    localparam STAGES            = multistage_fanout_STAGES           (FANOUT_FACTOR, FANOUT_SIZE),
    localparam PRE_FANOUT_SIZE   = multistage_fanout_PRE_FANOUT_SIZE  (FANOUT_FACTOR, STAGES),
    localparam FINAL_FANOUT_SIZE = multistage_fanout_FINAL_FANOUT_SIZE(FANOUT_FACTOR, STAGES),
    localparam LATENCY           = multistage_fanout_LATENCY          (IMMEDIATE_START_FANOUT, STAGES)
) (
    input clk_i
);
    logic [DATA_WIDTH - 1 : 0] data_i;
    logic                      valid_i;

    logic [FINAL_FANOUT_SIZE][DATA_WIDTH - 1 : 0] data_o;
    logic [FINAL_FANOUT_SIZE][0:0]                valid_o;
endinterface
`endif 