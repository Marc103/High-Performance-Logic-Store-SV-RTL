`ifndef ALIGNER_INF
    `define ALIGNER_INF
interface aligner_inf #(
    parameter DATA_WIDTH,
    parameter SIZE,
    parameter REGISTERED_IN,
    parameter START_SYMBOL_FANOUT_FACTOR,
    parameter REGISTERED_IN_START_SYMBOL,
    parameter REGISTERED_IN_EQUAL,
    parameter REGISTERED_IN_PRIORITY_ENCODER,
    parameter REGISTERED_IN_REDUCTION_TREE,
    parameter REGISTERED_IN_MULTISTAGE_MUX,
    parameter LUTX_EQUAL,
    parameter LUTX_PRIORITY_ENCODER,
    parameter LUTX_REDUCTION_TREE,
    parameter LUTX_MULTISTAGE_MUX,
    parameter GRADE_EQUAL,
    parameter GRADE_PRIORITY_ENCODER,
    parameter GRADE_REDUCTION_TREE,
    parameter GRADE_MULTISTAGE_MUX,

    ////////////////////////////////////////////////////////////////
    // Globally Defined Locally Set Parameters
    localparam START_SYMBOL_STAGES = multistage_fanout_STAGES(START_SYMBOL_FANOUT_FACTOR, SIZE),
    localparam START_SYMBOL_LATENCY = multistage_fanout_LATENCY(REGISTERED_IN_START_SYMBOL, START_SYMBOL_STAGES),
    localparam EQUAL_LATENCY = equal_LATENCY(REGISTERED_IN_EQUAL, GRADE_EQUAL),
    localparam PRIORITY_ENCODER_ENCODE_GROUPS = priority_encoder_ENCODE_GROUPS(SIZE, LUTX_PRIORITY_ENCODER),
    localparam PRIORITY_ENCODER_ENCODE_DEPTH = priority_encoder_ENCODE_DEPTH(PRIORITY_ENCODER_ENCODE_GROUPS),
    localparam PRIORITY_ENCODER_ENCODE_FIRST_LAYER_LATENCY = max_LATENCY(1, GRADE_PRIORITY_ENCODER),
    localparam PRIORITY_ENCODER_ENCODE_REST_LAYERS_LATENCY = max_LATENCY(0, GRADE_PRIORITY_ENCODER),
    localparam PRIORITY_ENCODER_LATENCY = priority_encoder_LATENCY(
        REGISTERED_IN_PRIORITY_ENCODER,
        PRIORITY_ENCODER_ENCODE_DEPTH,
        PRIORITY_ENCODER_ENCODE_FIRST_LAYER_LATENCY,
        PRIORITY_ENCODER_ENCODE_REST_LAYERS_LATENCY
    ),
    localparam REDUCTION_TREE_GROUP_SIZE = reduction_tree_GROUP_SIZE(LUTX_REDUCTION_TREE, GRADE_REDUCTION_TREE),
    localparam REDUCTION_TREE_STAGES = reduction_tree_STAGES(REDUCTION_TREE_GROUP_SIZE, SIZE),
    localparam REDUCTION_TREE_LATENCY = reduction_tree_LATENCY(REGISTERED_IN_REDUCTION_TREE, REDUCTION_TREE_STAGES),
    localparam MULTISTAGE_MUX_SELECTOR_WIDTH = multistage_mux_SELECTOR_WIDTH(SIZE),
    localparam MULTISTAGE_MUX_GROUP_SELECTOR_WIDTH = multistage_mux_GROUP_SELECTOR_WIDTH(LUTX_MULTISTAGE_MUX, GRADE_MULTISTAGE_MUX),
    localparam MULTISTAGE_MUX_GROUP_SIZE = multistage_mux_GROUP_SIZE(MULTISTAGE_MUX_GROUP_SELECTOR_WIDTH),
    localparam MULTISTAGE_MUX_STAGES = multistage_mux_STAGES(MULTISTAGE_MUX_GROUP_SIZE, SIZE),
    localparam MULTISTAGE_MUX_LATENCY = multistage_mux_LATENCY(REGISTERED_IN_MULTISTAGE_MUX, MULTISTAGE_MUX_STAGES),
    localparam PARTIAL_LATENCY = aligner_PARTIAL_LATENCY(
        START_SYMBOL_LATENCY,
        EQUAL_LATENCY,
        PRIORITY_ENCODER_LATENCY,
        REDUCTION_TREE_LATENCY
    ),
    localparam LATENCY = aligner_LATENCY(REGISTERED_IN, PARTIAL_LATENCY, MULTISTAGE_MUX_LATENCY)
) (
    input clk_i
);
    logic [SIZE - 1 : 0][DATA_WIDTH - 1 : 0] data_i;
    logic               [DATA_WIDTH - 1 : 0] start_symbol_i;

    logic [SIZE - 1 : 0][DATA_WIDTH - 1 : 0] aligned_o;
    logic                                    matched_o;

    // testbench sequencing signals
    logic start_sequence;
    logic end_sequence;
    logic end_last_sequence;
    logic idle;
endinterface
`endif
