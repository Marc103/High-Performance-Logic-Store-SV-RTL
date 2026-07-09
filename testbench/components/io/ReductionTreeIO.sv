import constant_functions_pkg::*;

class ReductionTreeIO #(
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
);

    `REDUCTION_TREE_IO_IN_STRUCT(DATA_WIDTH)
    `REDUCTION_TREE_IO_OUT_STRUCT

    reduction_tree_io_in_t reduction_tree_io_in_q[$];
    reduction_tree_io_out_t reduction_tree_io_out_q[$];

    // Sequencing Info
    bit idle [$];
    logic unsigned [7:0] error_state[$];
    logic end_last_sequence = 0;

    function new ();
    endfunction

endclass
