/*
Equal Tree
Compares if two inputs are equal using a comparison tree instead of adders, which is
a much more area efficient approach.

DATA_WIDTH:
- Data width.

REGISTERED_IN [0, 1]:
- If 1, inputs are registered, increasing latency by 1 cycle,
  else, inputs are direct.

LUTX [2,..]:
- Size of primitive LUTs and should be set to the primitive LUT size of FPGA.
  Tells us by how much to reduce the input by for each stage. I.e 36 inputs with
  LUT6 goes 36 -> 6 -> 1. But the first stage reduction is optimal with even numbered
  LUT size, i.e a LUT3, only 2 inputs are used to compare bits since 3 / 2 = 2 (floor).

GRADE [1,2]:
- Determines logic levels per stage. I.e if LUTX = 4, GRADE = 2, then an input of
  of 16 gets reduced in one step 16 -> 1 instead of 
  16 -> 4 -> 1.

*/

import constant_functions_pkg::*;

module equal_tree #(
    parameter DATA_WIDTH,
    parameter REGISTERED_IN,
    parameter LUTX,
    parameter GRADE,

    ////////////////////////////////////////////////////////////////
    // Globally Defined Locally Set Parameters
    localparam LUTX_HALF_GRADED             = equal_tree_LUTX_HALF_GRADED            (LUTX, GRADE),
    localparam PADDED_WIDTH                 = equal_tree_PADDED_WIDTH                (DATA_WIDTH, LUTX_HALF_GRADED),
    localparam GROUPS                       = equal_tree_GROUPS                      (PADDED_WIDTH, LUTX_HALF_GRADED),
    localparam REDUCTION_TREE_GROUP_SIZE    = reduction_tree_GROUP_SIZE              (LUTX, GRADE),
    localparam REDUCTION_TREE_STAGES        = reduction_tree_STAGES                  (REDUCTION_TREE_GROUP_SIZE, GROUPS),
    localparam REDUCTION_TREE_LATENCY       = reduction_tree_LATENCY                 (1, REDUCTION_TREE_STAGES),
    localparam LATENCY                      = equal_tree_LATENCY                     (REGISTERED_IN, GROUPS, REDUCTION_TREE_LATENCY)
) (
    input clk_i,

    input [DATA_WIDTH - 1 : 0] data_a_i,
    input [DATA_WIDTH - 1 : 0] data_b_i,

    output eq_o
);

    logic [DATA_WIDTH - 1 : 0] data_a;
    logic [DATA_WIDTH - 1 : 0] data_b;

    logic [DATA_WIDTH - 1 : 0] data_a_g;
    logic [DATA_WIDTH - 1 : 0] data_b_g;

    always@(posedge clk_i) begin
        data_a <= data_a_i;
        data_b <= data_b_i;
    end

    assign data_a_g = (REGISTERED_IN == 1) ? data_a : data_a_i;
    assign data_b_g = (REGISTERED_IN == 1) ? data_b : data_b_i;

    ////////////////////////////////////////////////////////////////
    // Stage 1
    logic [PADDED_WIDTH - 1 : 0] data_a_g_padded;
    logic [PADDED_WIDTH - 1 : 0] data_b_g_padded;
    always_comb begin
        data_a_g_padded = 0;
        data_b_g_padded = 0;
        data_a_g_padded[DATA_WIDTH - 1 : 0] = data_a_g;
        data_b_g_padded[DATA_WIDTH - 1 : 0] = data_b_g;
    end

    logic [GROUPS - 1 : 0] compared;
    always_comb begin
        for(int g = 0; g < GROUPS; g++) begin
            compared[g] = data_a_g_padded[(g * LUTX_HALF_GRADED) +: LUTX_HALF_GRADED] ==
                          data_b_g_padded[(g * LUTX_HALF_GRADED) +: LUTX_HALF_GRADED] ? 1 : 0;
        end
    end

    ////////////////////////////////////////////////////////////////
    // Stage 2+
    logic eq;
    generate
        if(GROUPS > 1) begin
            reduction_tree #(
                .DATA_WIDTH(GROUPS),
                .GATE(0),
                .REGISTERED_IN(1),
                .LUTX(LUTX),
                .GRADE(GRADE)
            ) and_r_tree (
                .clk_i(clk_i),
                .data_i(compared),
                .reduced_o(eq)
            );
        end
    endgenerate

    assign eq_o = GROUPS > 1 ? eq : compared[0];

endmodule
