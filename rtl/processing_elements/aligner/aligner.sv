/*
Aligner
Aligns the start of the element as according to a starting symbol. i.e
[x, x, start, s2] <- [s1, s0, a3, a2] <- [a1, a0, b3, b2] <- [b1, b0, ..., ...] <- ...
should be rotated and appear as:
[start, s2, s1, s0] <- [a3, a2, a1, a0] <- [b3, b2, b1, b0] <- ...
on the output.

DATA_WIDTH:
- Data width of one element

SIZE:
- Number of elements that determine a word. I.e if DATA_WIDTH = 8, and SIZE = 4, then
  a word is defined as having the packed type [3:0][7:0], in other words, in this specific case,
  a word consists of 4 bytes.

REGISTERED_IN [0, 1]:
- If 1, inputs are registered, increasing latency by 1 cycle,
  else, inputs are direct.

LUTX_*:
- LUTXs of the the respective components in the module

GRADE_*:
- GRADEs of the respective components in the module

START_SYMBOL_FANOUT_FACTOR:
- The start symbol could potentially be compared to many elements if SIZE is big, thus we have a fanout module
  included. Hence this parameter sets the fanout factor desired of the start symbol.

*/

import constant_functions_pkg::*; 

module aligner #(
    parameter DATA_WIDTH,
    parameter SIZE,
    parameter REGISTERED_IN,

    // start symbol fanout
    parameter START_SYMBOL_FANOUT_FACTOR,

    // REGISTERED_IN respective
    parameter REGISTERED_IN_START_SYMBOL,
    parameter REGISTERED_IN_EQUAL,
    parameter REGISTERED_IN_PRIORITY_ENCODER,
    parameter REGISTERED_IN_REDUCTION_TREE,
    parameter REGISTERED_IN_MULTISTAGE_MUX,

    // LUTX respective
    parameter LUTX_EQUAL,
    parameter LUTX_PRIORITY_ENCODER,
    parameter LUTX_REDUCTION_TREE,
    parameter LUTX_MULTISTAGE_MUX,

    // GRADE respective
    parameter GRADE_EQUAL,
    parameter GRADE_PRIORITY_ENCODER,
    parameter GRADE_REDUCTION_TREE,
    parameter GRADE_MULTISTAGE_MUX,

    ////////////////////////////////////////////////////////////////
    // Globally Defined Locally Set Parameters

    // start symbol fanout
    localparam START_SYMBOL_STAGES            = multistage_fanout_STAGES           (START_SYMBOL_FANOUT_FACTOR, SIZE),
    localparam START_SYMBOL_FINAL_FANOUT_SIZE = multistage_fanout_FINAL_FANOUT_SIZE(START_SYMBOL_FANOUT_FACTOR, START_SYMBOL_STAGES),
    localparam START_SYMBOL_LATENCY           = multistage_fanout_LATENCY          (REGISTERED_IN_START_SYMBOL, START_SYMBOL_STAGES),

    // equal 
    localparam EQUAL_LATENCY = equal_LATENCY(REGISTERED_IN_EQUAL, GRADE_EQUAL),

    // priority encoder
    localparam                                     PRIORITY_ENCODER_ENCODE_GROUPS              = priority_encoder_ENCODE_GROUPS      (SIZE, LUTX_PRIORITY_ENCODER),
    localparam                                     PRIORITY_ENCODER_ENCODE_DEPTH               = priority_encoder_ENCODE_DEPTH       (PRIORITY_ENCODER_ENCODE_GROUPS),
    localparam                                     PRIORITY_ENCODER_ENCODE_FIRST_LAYER_LATENCY = max_LATENCY                         (1, GRADE_PRIORITY_ENCODER),
    localparam                                     PRIORITY_ENCODER_ENCODE_REST_LAYERS_LATENCY = max_LATENCY                         (0, GRADE_PRIORITY_ENCODER),
    localparam                                     PRIORITY_ENCODER_LATENCY                    = priority_encoder_LATENCY(
                                                                                                     REGISTERED_IN_PRIORITY_ENCODER, 
                                                                                                     PRIORITY_ENCODER_ENCODE_DEPTH, 
                                                                                                     PRIORITY_ENCODER_ENCODE_FIRST_LAYER_LATENCY, 
                                                                                                     PRIORITY_ENCODER_ENCODE_REST_LAYERS_LATENCY),
    localparam                                     PRIORITY_ENCODER_OUTPUT_DATA_WIDTH          = priority_encoder_OUTPUT_DATA_WIDTH  (SIZE),

    // reduction tree
    localparam                                      REDUCTION_TREE_GROUP_SIZE           = reduction_tree_GROUP_SIZE(LUTX_REDUCTION_TREE, GRADE_REDUCTION_TREE),
    localparam                                      REDUCTION_TREE_STAGES               = reduction_tree_STAGES (REDUCTION_TREE_GROUP_SIZE, SIZE),
    localparam                                      REDUCTION_TREE_LATENCY              = reduction_tree_LATENCY(REGISTERED_IN_REDUCTION_TREE, REDUCTION_TREE_STAGES),

    // multistage mux
    localparam                                      MULTISTAGE_MUX_SELECTOR_WIDTH       = multistage_mux_SELECTOR_WIDTH(SIZE),
    localparam                                      MULTISTAGE_MUX_GROUP_SELECTOR_WIDTH = multistage_mux_GROUP_SELECTOR_WIDTH(LUTX_MULTISTAGE_MUX, GRADE_MULTISTAGE_MUX),
    localparam                                      MULTISTAGE_MUX_GROUP_SIZE           = multistage_mux_GROUP_SIZE(MULTISTAGE_MUX_GROUP_SELECTOR_WIDTH),
    localparam                                      MULTISTAGE_MUX_STAGES               = multistage_mux_STAGES(MULTISTAGE_MUX_GROUP_SIZE, SIZE),
    localparam                                      MULTISTAGE_MUX_LATENCY              = multistage_mux_LATENCY(REGISTERED_IN_MULTISTAGE_MUX, MULTISTAGE_MUX_STAGES),
    
    // aligner locals
    localparam SIZE_COMBINED   = aligner_SIZE_COMBINED(SIZE),
    localparam FLATTEN_WIDTH   = aligner_FLATTEN_WIDTH(DATA_WIDTH, SIZE),
    localparam PARTIAL_LATENCY = aligner_PARTIAL_LATENCY(
                                    START_SYMBOL_LATENCY,
                                    EQUAL_LATENCY,
                                    PRIORITY_ENCODER_LATENCY,
                                    REDUCTION_TREE_LATENCY
    ),
    localparam LATENCY =      aligner_LATENCY(REGISTERED_IN, PARTIAL_LATENCY, MULTISTAGE_MUX_LATENCY),

    localparam ADJUST_PRIORITY_ENCODER_LATENCY = aligner_ADJUST_PRIORITY_ENCODER_LATENCY(PRIORITY_ENCODER_LATENCY, REDUCTION_TREE_LATENCY),
    localparam ADJUST_REDUCTION_TREE_LATENCY   = aligner_ADJUST_REDUCTION_TREE_LATENCY(PRIORITY_ENCODER_LATENCY, REDUCTION_TREE_LATENCY) 
) (
    input                                     clk_i,
    input  [SIZE - 1 : 0][DATA_WIDTH - 1 : 0] data_i,
    input                [DATA_WIDTH - 1 : 0] start_symbol_i,

    output [SIZE - 1 : 0][DATA_WIDTH - 1 : 0]                         aligned_o,
    output                                                            matched_o,
    output               [PRIORITY_ENCODER_OUTPUT_DATA_WIDTH - 1 : 0] selector_o
);


    logic [SIZE - 1 : 0][DATA_WIDTH - 1 : 0] data;
    logic [SIZE - 1 : 0][DATA_WIDTH - 1 : 0] data_g;

    logic [DATA_WIDTH - 1 : 0] start_symbol;
    logic [DATA_WIDTH - 1 : 0] start_symbol_g;

    always@(posedge clk_i) begin
        data         <= data_i;
        start_symbol <= start_symbol_i;
    end

    assign data_g = (REGISTERED_IN == 1) ? data : data_i;
    assign start_symbol_g = (REGISTERED_IN == 1) ? start_symbol : start_symbol_i;

    // data pipeline
    logic[PARTIAL_LATENCY : 0][SIZE - 1 : 0][DATA_WIDTH - 1 : 0] data_pipeline;
    always@(posedge clk_i) begin
        for(int r = 1; r <= PARTIAL_LATENCY; r++) begin
            if(r == 1) begin
                data_pipeline[r] <= data_g;
            end else begin
                data_pipeline[r] <= data_pipeline[r - 1];
            end
        end
    end

    // Fanout Start Symbol
    // need to fanout start symbol since it could potentially be compared to many values.
    logic [START_SYMBOL_FINAL_FANOUT_SIZE - 1 : 0][DATA_WIDTH - 1 : 0] start_symbol_fanout_o;
    multistage_fanout #(
        .DATA_WIDTH(DATA_WIDTH),
        .FANOUT_SIZE(SIZE),
        .FANOUT_FACTOR(START_SYMBOL_FANOUT_FACTOR),
        .REGISTERED_IN(REGISTERED_IN_START_SYMBOL)
    ) symbol_fanout_inst (
        .clk_i(clk_i),
        .data_i(start_symbol_g),
        .data_o(start_symbol_fanout_o)
    );

    // Equal 
    // comparing against start_symbol
    logic [SIZE - 1 : 0] start_symbol_eq_o;
    generate
        for(genvar i = 0; i < SIZE; i++) begin
            for(genvar cond = (START_SYMBOL_LATENCY == 0); cond == 1; cond = 0) begin
                equal #(
                    .DATA_WIDTH(DATA_WIDTH),
                    .REGISTERED_IN(REGISTERED_IN_EQUAL),
                    .GRADE(GRADE_EQUAL)
                ) equal_inst (
                    .clk_i(clk_i),
                    .data_a_i(start_symbol_fanout_o[i]),
                    .data_b_i(data_g[i]),
                    .eq_o(start_symbol_eq_o[i])
                );  
            end
            for(genvar cond = (START_SYMBOL_LATENCY != 0); cond == 1; cond = 0) begin
                equal #(
                    .DATA_WIDTH(DATA_WIDTH),
                    .REGISTERED_IN(REGISTERED_IN_EQUAL),
                    .GRADE(GRADE_EQUAL)
                ) equal_inst (
                    .clk_i(clk_i),
                    .data_a_i(start_symbol_fanout_o[i]),
                    .data_b_i(data_pipeline[START_SYMBOL_LATENCY][i]),
                    .eq_o(start_symbol_eq_o[i])
                );  
            end
        end
    endgenerate

    // Or Tree
    // on the comparison results, to determine at least one match
    logic or_reduced_o;
    reduction_tree #(
        .DATA_WIDTH(SIZE),
        .GATE(1),
        .REGISTERED_IN(REGISTERED_IN_REDUCTION_TREE),
        .LUTX(LUTX_REDUCTION_TREE),
        .GRADE(GRADE_REDUCTION_TREE)
    ) or_reduction_tree_inst (
        .clk_i(clk_i),
        .data_i(start_symbol_eq_o),
        .reduced_o(or_reduced_o)
    );

    logic adj_or_reduced_o;
    pipe #(
        .DATA_WIDTH(1),
        .LATENCY(ADJUST_REDUCTION_TREE_LATENCY)
    ) adj_or_reduced_pipe (
        .clk_i(clk_i),
        .data_i(or_reduced_o),
        .data_o(adj_or_reduced_o)
    );

    // Priority Encoder
    // on the comparison results
    logic [PRIORITY_ENCODER_OUTPUT_DATA_WIDTH - 1 : 0] priority_encoded_o;
    priority_encoder #(
        .INPUT_DATA_WIDTH(SIZE),
        .REGISTERED_IN(REGISTERED_IN_PRIORITY_ENCODER),
        .LUTX(LUTX_PRIORITY_ENCODER),
        .GRADE(GRADE_PRIORITY_ENCODER)
    ) priority_encoder_inst (
        .clk_i(clk_i),
        .priority_i(start_symbol_eq_o),
        .priority_encoded_o(priority_encoded_o)
    );

    logic [PRIORITY_ENCODER_OUTPUT_DATA_WIDTH - 1 : 0] adj_priority_encoded_o;
    pipe #(
        .DATA_WIDTH(PRIORITY_ENCODER_OUTPUT_DATA_WIDTH),
        .LATENCY(ADJUST_PRIORITY_ENCODER_LATENCY)
    ) adj_priority_encoded_pipe (
        .clk_i(clk_i),
        .data_i(priority_encoded_o),
        .data_o(adj_priority_encoded_o)
    );
    
    // Selector update logic, only update if a match is found.
    logic [PRIORITY_ENCODER_OUTPUT_DATA_WIDTH - 1 : 0] sel;
    always@(posedge clk_i) begin
        if(adj_or_reduced_o) begin
            sel <= adj_priority_encoded_o;
        end else begin
            sel <= sel;
        end
    end

    // Selector tracking
    logic [PRIORITY_ENCODER_OUTPUT_DATA_WIDTH - 1 : 0] sel_pipe_o;
    pipe #(
        .DATA_WIDTH(PRIORITY_ENCODER_OUTPUT_DATA_WIDTH),
        .LATENCY(MULTISTAGE_MUX_LATENCY)
    ) sel_pipe (
        .clk_i(clk_i),
        .data_i(sel),
        .data_o(sel_pipe_o)
    );

    assign selector_o = sel_pipe_o;

    // Matched tracking, discerns whether a match occured
    logic matched;
    always@(posedge clk_i) begin
        matched <= adj_or_reduced_o;
    end

    logic matched_pipe_o;
    pipe #(
        .DATA_WIDTH(1),
        .LATENCY(MULTISTAGE_MUX_LATENCY)
    ) matched_pipe (
        .clk_i(clk_i),
        .data_i(matched),
        .data_o(matched_pipe_o)
    );

    assign matched_o = matched_pipe_o;

    // Mux
    // mux according to priority encoder out
    logic [SIZE_COMBINED - 1 : 0][DATA_WIDTH - 1 : 0] combine_data;
    logic [SIZE - 1 : 0][SIZE - 1 : 0][DATA_WIDTH - 1 : 0] mux_data;
    logic [SIZE - 1 : 0][FLATTEN_WIDTH - 1 : 0] mux_flatten_data;
    always_comb begin
        for(int i = 0; i < SIZE; i++) begin
            if(PARTIAL_LATENCY == 1) begin
                combine_data[i]        = data_g          [i];
                combine_data[SIZE + i] = data_pipeline[1][i];
            end else begin
                combine_data[i]        = data_pipeline[PARTIAL_LATENCY - 1][i];
                combine_data[SIZE + i] = data_pipeline[PARTIAL_LATENCY - 0][i];
            end
        end
        for(int mux_group = 0; mux_group < SIZE; mux_group++) begin
            for(int i = 0; i < SIZE; i++) begin
                mux_data[mux_group][i] = combine_data[1 + mux_group + i];
            end
        end
        for(int mux_group = 0; mux_group < SIZE; mux_group++) begin
            for(int i = 0; i < SIZE; i++)
            mux_flatten_data[mux_group][(i * DATA_WIDTH) +: DATA_WIDTH] = mux_data[mux_group][i];
        end
    end

    logic [FLATTEN_WIDTH - 1 : 0] mux_data_o;

    multistage_mux #(
        .DATA_WIDTH(FLATTEN_WIDTH),
        .SIZE(SIZE),
        .REGISTERED_IN(REGISTERED_IN_MULTISTAGE_MUX),
        .LUTX(LUTX_MULTISTAGE_MUX),
        .GRADE(GRADE_MULTISTAGE_MUX)
    ) multistage_mux_inst (
        .clk_i(clk_i),
        .data_i(mux_flatten_data),
        .sel_i(sel),
        .data_o(mux_data_o)
    );

    logic [SIZE - 1 : 0][DATA_WIDTH - 1 : 0] unflatten_mux_data;
    always_comb begin
        for(int i = 0; i < SIZE; i++) begin
            unflatten_mux_data[i] = mux_data_o[(i * DATA_WIDTH) +: DATA_WIDTH];
        end
    end

    assign aligned_o = unflatten_mux_data;
endmodule
