import constant_functions_pkg::*;

class EqualTreeIO #(
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
);

    `EQUAL_TREE_IO_IN_STRUCT(DATA_WIDTH)
    `EQUAL_TREE_IO_OUT_STRUCT

    equal_tree_io_in_t equal_tree_io_in_q[$];
    equal_tree_io_out_t equal_tree_io_out_q[$];

    // Sequencing Info
    bit idle [$];
    logic unsigned [7:0] error_state[$];
    logic end_last_sequence = 0;

    function new ();
    endfunction

endclass
