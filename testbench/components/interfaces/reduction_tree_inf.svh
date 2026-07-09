`ifndef REDUCTION_TREE_INF 
    `define REDUCTION_TREE_INF
interface reduction_tree_inf #(
    parameter DATA_WIDTH,
    parameter GATE,
    parameter REGISTERED_IN,
    parameter LUTX,
    parameter GRADE,

    ////////////////////////////////////////////////////////////////
    // Globally Defined Locally Set Parameters
    localparam GROUP_SIZE = reduction_tree_GROUP_SIZE(LUTX, GRADE),
    localparam STAGES     = reduction_tree_STAGES(GROUP_SIZE, DATA_WIDTH),
    localparam LATENCY    = reduction_tree_LATENCY(REGISTERED_IN, STAGES)
) (
    input clk_i
);
    logic [DATA_WIDTH - 1 : 0] data_i;

    logic reduced_o;

    // testbench sequencing signals
    logic start_sequence;
    logic end_sequence;
    logic end_last_sequence;
    logic idle;
endinterface
`endif 
