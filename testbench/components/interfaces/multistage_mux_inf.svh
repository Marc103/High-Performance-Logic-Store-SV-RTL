`ifndef MULTISTAGE_MUX_INF 
    `define MULTISTAGE_MUX_INF
interface multistage_mux_inf #(
    parameter DATA_WIDTH,
    parameter SIZE,
    parameter REGISTERED_IN,
    parameter LUTX,
    parameter GRADE,

    ////////////////////////////////////////////////////////////////
    // Globally Defined Locally Set Parameters
    localparam SELECTOR_WIDTH       = multistage_mux_SELECTOR_WIDTH(SIZE),
    localparam GROUP_SELECTOR_WIDTH = multistage_mux_GROUP_SELECTOR_WIDTH(LUTX, GRADE),
    localparam GROUP_SIZE           = multistage_mux_GROUP_SIZE(GROUP_SELECTOR_WIDTH),
    localparam STAGES               = multistage_mux_STAGES(GROUP_SIZE, SIZE),
    localparam LATENCY              = multistage_mux_LATENCY(REGISTERED_IN, STAGES)
) (
    input clk_i
);
    logic [SIZE - 1 : 0][DATA_WIDTH - 1 : 0]     data_i;
    logic               [SELECTOR_WIDTH - 1 : 0] sel_i;
    logic               [DATA_WIDTH - 1 : 0]     data_o;

    // testbench sequencing signals
    logic start_sequence;
    logic end_sequence;
    logic end_last_sequence;
    logic idle;
endinterface
`endif 
