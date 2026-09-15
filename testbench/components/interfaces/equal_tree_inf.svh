`ifndef EQUAL_TREE_INF
    `define EQUAL_TREE_INF
interface equal_tree_inf #(
    parameter DATA_WIDTH,
    parameter REGISTERED_IN,
    parameter LUTX,
    parameter GRADE,

    ////////////////////////////////////////////////////////////////
    // Globally Defined Locally Set Parameters
    localparam LUTX_HALF_GRADED          = equal_tree_LUTX_HALF_GRADED(LUTX, GRADE),
    localparam PADDED_WIDTH              = equal_tree_PADDED_WIDTH(DATA_WIDTH, LUTX_HALF_GRADED),
    localparam GROUPS                    = equal_tree_GROUPS(PADDED_WIDTH, LUTX_HALF_GRADED),
    localparam REDUCTION_TREE_GROUP_SIZE = reduction_tree_GROUP_SIZE(LUTX, GRADE),
    localparam REDUCTION_TREE_STAGES     = reduction_tree_STAGES(REDUCTION_TREE_GROUP_SIZE, GROUPS),
    localparam REDUCTION_TREE_LATENCY    = reduction_tree_LATENCY(1, REDUCTION_TREE_STAGES),
    localparam LATENCY                   = equal_tree_LATENCY(REGISTERED_IN, GROUPS, REDUCTION_TREE_LATENCY)
) (
    input clk_i
);
    logic [DATA_WIDTH - 1 : 0] data_a_i;
    logic [DATA_WIDTH - 1 : 0] data_b_i;

    logic eq_o;

    // testbench sequencing signals
    logic start_sequence;
    logic end_sequence;
    logic end_last_sequence;
    logic idle;
endinterface
`endif 
