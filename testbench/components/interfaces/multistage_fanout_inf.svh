`ifndef MULTISTAGE_FANOUT_INF 
    `define MULTISTAGE_FANOUT_INF
interface multistage_fanout_inf #(
    parameter DATA_WIDTH,
    parameter FANOUT_SIZE,
    parameter FANOUT_FACTOR,
    parameter IMMEDIATE_START_FANOUT = 0,

    ////////////////////////////////////////////////////////////////
    // Local parameters
    localparam STAGES            = clog_base(FANOUT_FACTOR, FANOUT_SIZE),
    localparam PRE_FANOUT_SIZE   = FANOUT_FACTOR ** (STAGES - 1),
    localparam FINAL_FANOUT_SIZE = FANOUT_FACTOR ** STAGES,
    localparam LATENCY = (IMMEDIATE_START_FANOUT == 1) ? STAGES - 1 : STAGES 
) (
    input clk_i
);
    logic [DATA_WIDTH - 1 : 0] data_i;
    logic                      valid_i;

    logic [DATA_WIDTH - 1 : 0] data_o [FINAL_FANOUT_SIZE];
    logic                      valid_o [FINAL_FANOUT_SIZE];
endinterface
`endif 