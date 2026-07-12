`timescale 1ns / 1ps

import constant_functions_pkg::*;

module top #(
    ////////////////////////////////////////////////////////////////
    // shared
    localparam CLK_DATA_WIDTH = 12,

    ////////////////////////////////////////////////////////////////
    // multistage_fanout
    localparam MULTISTAGE_FANOUT_DATA_WIDTH = 12,
    localparam MULTISTAGE_FANOUT_FANOUT_SIZE = 17,
    localparam MULTISTAGE_FANOUT_FANOUT_FACTOR = 4,
    localparam MULTISTAGE_FANOUT_IMMEDIATE_START_FANOUT = 1,
    localparam MULTISTAGE_FANOUT_STAGES =
        multistage_fanout_STAGES(
            MULTISTAGE_FANOUT_FANOUT_FACTOR,
            MULTISTAGE_FANOUT_FANOUT_SIZE
        ),
    localparam MULTISTAGE_FANOUT_FINAL_FANOUT_SIZE =
        multistage_fanout_FINAL_FANOUT_SIZE(
            MULTISTAGE_FANOUT_FANOUT_FACTOR,
            MULTISTAGE_FANOUT_STAGES
        ),

    ////////////////////////////////////////////////////////////////
    // equal
    localparam EQUAL_DATA_WIDTH = 12,
    localparam EQUAL_REGISTERED_IN = 1,
    localparam EQUAL_GRADE = 1,

    ////////////////////////////////////////////////////////////////
    // reduction_tree
    localparam REDUCTION_TREE_DATA_WIDTH = 17,
    localparam REDUCTION_TREE_GATE = 1,
    localparam REDUCTION_TREE_REGISTERED_IN = 1,
    localparam REDUCTION_TREE_LUTX = 6,
    localparam REDUCTION_TREE_GRADE = 1,

    ////////////////////////////////////////////////////////////////
    // priority_encoder
    localparam PRIORITY_ENCODER_INPUT_DATA_WIDTH = 17,
    localparam PRIORITY_ENCODER_REGISTERED_IN = 1,
    localparam PRIORITY_ENCODER_LUTX = 6,
    localparam PRIORITY_ENCODER_GRADE = 1,
    localparam PRIORITY_ENCODER_OUTPUT_DATA_WIDTH =
        priority_encoder_OUTPUT_DATA_WIDTH(PRIORITY_ENCODER_INPUT_DATA_WIDTH),

    ////////////////////////////////////////////////////////////////
    // multistage_mux
    localparam MULTISTAGE_MUX_DATA_WIDTH = 12,
    localparam MULTISTAGE_MUX_SIZE = 17,
    localparam MULTISTAGE_MUX_REGISTERED_IN = 1,
    localparam MULTISTAGE_MUX_LUTX = 6,
    localparam MULTISTAGE_MUX_GRADE = 1,
    localparam MULTISTAGE_MUX_SELECTOR_WIDTH =
        multistage_mux_SELECTOR_WIDTH(MULTISTAGE_MUX_SIZE),

    ////////////////////////////////////////////////////////////////
    // aligner
    localparam ALIGNER_DATA_WIDTH = 12,
    localparam ALIGNER_SIZE = 17,
    localparam ALIGNER_REGISTERED_IN = 1,

    localparam ALIGNER_START_SYMBOL_FANOUT_FACTOR = 4,
    localparam ALIGNER_START_SYMBOL_IMMEDIATE_START_FANOUT = 1,

    localparam ALIGNER_REGISTERED_IN_PRIORITY_ENCODER = 1,
    localparam ALIGNER_REGISTERED_IN_REDUCTION_TREE = 1,
    localparam ALIGNER_REGISTERED_IN_MULTISTAGE_MUX = 1,

    localparam ALIGNER_LUTX_EQUAL = 6,
    localparam ALIGNER_LUTX_PRIORITY_ENCODER = 6,
    localparam ALIGNER_LUTX_REDUCTION_TREE = 6,
    localparam ALIGNER_LUTX_MULTISTAGE_MUX = 6,

    localparam ALIGNER_GRADE_EQUAL = 1,
    localparam ALIGNER_GRADE_PRIORITY_ENCODER = 1,
    localparam ALIGNER_GRADE_REDUCTION_TREE = 1,
    localparam ALIGNER_GRADE_MULTISTAGE_MUX = 1
)(
    input clk_i,

    ////////////////////////////////////////////////////////////////
    // multistage_fanout
    input  [MULTISTAGE_FANOUT_DATA_WIDTH - 1 : 0] multistage_fanout_data_i,
    output [MULTISTAGE_FANOUT_FINAL_FANOUT_SIZE - 1 : 0][MULTISTAGE_FANOUT_DATA_WIDTH - 1 : 0] multistage_fanout_data_o,

    ////////////////////////////////////////////////////////////////
    // equal
    input  [EQUAL_DATA_WIDTH - 1 : 0] equal_data_a_i,
    input  [EQUAL_DATA_WIDTH - 1 : 0] equal_data_b_i,
    output                            equal_eq_o,

    ////////////////////////////////////////////////////////////////
    // reduction_tree
    input  [REDUCTION_TREE_DATA_WIDTH - 1 : 0] reduction_tree_data_i,
    output                                    reduction_tree_reduced_o,

    ////////////////////////////////////////////////////////////////
    // priority_encoder
    input  [PRIORITY_ENCODER_INPUT_DATA_WIDTH - 1 : 0]  priority_encoder_priority_i,
    output [PRIORITY_ENCODER_OUTPUT_DATA_WIDTH - 1 : 0] priority_encoder_priority_encoded_o,

    ////////////////////////////////////////////////////////////////
    // multistage_mux
    input  [MULTISTAGE_MUX_SIZE - 1 : 0][MULTISTAGE_MUX_DATA_WIDTH - 1 : 0] multistage_mux_data_i,
    input  [MULTISTAGE_MUX_SELECTOR_WIDTH - 1 : 0]                          multistage_mux_sel_i,
    output [MULTISTAGE_MUX_DATA_WIDTH - 1 : 0]                              multistage_mux_data_o,

    ////////////////////////////////////////////////////////////////
    // aligner
    input  [ALIGNER_SIZE - 1 : 0][ALIGNER_DATA_WIDTH - 1 : 0] aligner_data_i,
    input                   [ALIGNER_DATA_WIDTH - 1 : 0]      aligner_start_symbol_i,
    output [ALIGNER_SIZE - 1 : 0][ALIGNER_DATA_WIDTH - 1 : 0] aligner_aligned_o
);

    /*
    multistage_fanout #(
        .DATA_WIDTH(MULTISTAGE_FANOUT_DATA_WIDTH),
        .FANOUT_SIZE(MULTISTAGE_FANOUT_FANOUT_SIZE),
        .FANOUT_FACTOR(MULTISTAGE_FANOUT_FANOUT_FACTOR),
        .IMMEDIATE_START_FANOUT(MULTISTAGE_FANOUT_IMMEDIATE_START_FANOUT)
    ) dut (
        .clk_i(clk_i),

        .data_i(multistage_fanout_data_i),

        .data_o(multistage_fanout_data_o)
    );
    */

    /*
    equal #(
        .DATA_WIDTH(EQUAL_DATA_WIDTH),
        .REGISTERED_IN(EQUAL_REGISTERED_IN),
        .GRADE(EQUAL_GRADE)
    ) dut (
        .clk_i(clk_i),

        .data_a_i(equal_data_a_i),
        .data_b_i(equal_data_b_i),

        .eq_o(equal_eq_o)
    );
    */

    /*
    reduction_tree #(
        .DATA_WIDTH(REDUCTION_TREE_DATA_WIDTH),
        .GATE(REDUCTION_TREE_GATE),
        .REGISTERED_IN(REDUCTION_TREE_REGISTERED_IN),
        .LUTX(REDUCTION_TREE_LUTX),
        .GRADE(REDUCTION_TREE_GRADE)
    ) dut (
        .clk_i(clk_i),

        .data_i(reduction_tree_data_i),

        .reduced_o(reduction_tree_reduced_o)
    );
    */

    /*
    priority_encoder #(
        .INPUT_DATA_WIDTH(PRIORITY_ENCODER_INPUT_DATA_WIDTH),
        .REGISTERED_IN(PRIORITY_ENCODER_REGISTERED_IN),
        .LUTX(PRIORITY_ENCODER_LUTX),
        .GRADE(PRIORITY_ENCODER_GRADE)
    ) dut (
        .clk_i(clk_i),

        .priority_i(priority_encoder_priority_i),

        .priority_encoded_o(priority_encoder_priority_encoded_o)
    );
    */

    /*
    multistage_mux #(
        .DATA_WIDTH(MULTISTAGE_MUX_DATA_WIDTH),
        .SIZE(MULTISTAGE_MUX_SIZE),
        .REGISTERED_IN(MULTISTAGE_MUX_REGISTERED_IN),
        .LUTX(MULTISTAGE_MUX_LUTX),
        .GRADE(MULTISTAGE_MUX_GRADE)
    ) dut (
        .clk_i(clk_i),

        .data_i(multistage_mux_data_i),
        .sel_i(multistage_mux_sel_i),

        .data_o(multistage_mux_data_o)
    );
    */

    /*
    aligner #(
        .DATA_WIDTH(ALIGNER_DATA_WIDTH),
        .SIZE(ALIGNER_SIZE),
        .REGISTERED_IN(ALIGNER_REGISTERED_IN),

        // start symbol fanout
        .START_SYMBOL_FANOUT_FACTOR(ALIGNER_START_SYMBOL_FANOUT_FACTOR),
        .START_SYMBOL_IMMEDIATE_START_FANOUT(ALIGNER_START_SYMBOL_IMMEDIATE_START_FANOUT),

        // REGISTERED_IN respective
        .REGISTERED_IN_PRIORITY_ENCODER(ALIGNER_REGISTERED_IN_PRIORITY_ENCODER),
        .REGISTERED_IN_REDUCTION_TREE(ALIGNER_REGISTERED_IN_REDUCTION_TREE),
        .REGISTERED_IN_MULTISTAGE_MUX(ALIGNER_REGISTERED_IN_MULTISTAGE_MUX),

        // LUTX respective
        .LUTX_EQUAL(ALIGNER_LUTX_EQUAL),
        .LUTX_PRIORITY_ENCODER(ALIGNER_LUTX_PRIORITY_ENCODER),
        .LUTX_REDUCTION_TREE(ALIGNER_LUTX_REDUCTION_TREE),
        .LUTX_MULTISTAGE_MUX(ALIGNER_LUTX_MULTISTAGE_MUX),

        // GRADE respective
        .GRADE_EQUAL(ALIGNER_GRADE_EQUAL),
        .GRADE_PRIORITY_ENCODER(ALIGNER_GRADE_PRIORITY_ENCODER),
        .GRADE_REDUCTION_TREE(ALIGNER_GRADE_REDUCTION_TREE),
        .GRADE_MULTISTAGE_MUX(ALIGNER_GRADE_MULTISTAGE_MUX)
    ) dut (
        .clk_i(clk_i),

        .data_i(aligner_data_i),
        .start_symbol_i(aligner_start_symbol_i),

        .aligned_o(aligner_aligned_o)
    );
    */

endmodule
