/*
Reduction Tree
Performs logical reduction of given input. Supports
AND, OR, XOR, NAND, NOR, NXOR reduction.

DATA_WIDTH:
- Data width

GATE[0,1,2,3,4,5]:
- Which logical reduction to perform? 
0 - AND
1 - OR
2 - XOR
3 - NAND
4 - NOR
5 - NXOR

REGISTERED_IN [0, 1]:
- If 1, inputs are registered, increasing latency by 1 cycle,
  else, inputs are direct.

LUTX [1, ...]:
- Size of primitive LUTs and should be set to the primitive LUT size of FPGA.
  It is use to determine the base boolean logic capability. I.e a LUT6 can reduce
  a 6 input to 1 output.

GRADE [1, ...]:
- The grade tells us the logic depth allowed per stage. I.e with LUTX set to 6 and
GRADE set to 1, we will reduce the input at each layer by 6. However, if 
GRADE is set to 2 instead, this will allows us to do 6 -> 6, effectively a 36 inputs
in one step (2 logic depths). You could also artificially adjust the LUTX to something
like 11 but it will no longer be consistent with the grading system and so is not
advisable.
*/

import constant_functions_pkg::*; 

module reduction_tree #(
    parameter DATA_WIDTH,
    parameter GATE,
    parameter REGISTERED_IN,
    parameter LUTX,
    parameter GRADE,

    ////////////////////////////////////////////////////////////////
    // Globally Defined Locally Set Parameters
    localparam                                      STAGES               = reduction_tree_STAGES (LUTX, DATA_WIDTH),
    localparam int_t [SMALL - 1 : 0][SOLAR - 1 : 0] REDUCTION_TREE_MAP   = generic_tree_map      (STAGES, LUTX, DATA_WIDTH),
    localparam                                      LATENCY              = reduction_tree_LATENCY(REGISTERED_IN, STAGES)

) (
    input clk_i,
    
    input [DATA_WIDTH - 1 : 0] data_i,

    output data_o
);

    logic [DATA_WIDTH - 1 : 0] data;
    logic [DATA_WIDTH - 1 : 0] data_g;

    always@(posedge clk_i) begin
        data <= data_i;
    end

    assign data_g = (REGISTERED_IN == 1) ? data : data_i;

    logic [STAGES : 0][DATA_WIDTH - 1 : 0] reduce_data;
    logic [STAGES - 1 : 0][DATA_WIDTH - 1 : 0] reduce_data_pipeline;
    /*
    See schematic in 'reduction_tree.sv', follows similar pipeline structure
    */

    always_comb begin
        reduce_data[0]          = 'x;

        for(int row = 1; row <= STAGES; row++) begin
            for(int col = 0; col < DATA_WIDTH; col++) begin
                if(REDUCE_TREE_MAP[row][col] != 0) begin
                    logic [REDUCE_TREE_MAP[row - 1][(col * LUTX) + 0] - 1 : 0] group_reduce_data;

                    // wire inputs
                    group_reduce_data = 'x;
                    for(int g = 0; g < REDUCE_TREE_MAP[row - 1][(col * LUTX) + 0]; g++) begin
                        if(row == 1) begin
                            group_reduce_data[g] = data_g[(col * LUTX) + g];
                        end else begin
                            group_reduce_data[g] = reduce_data_pipeline[row - 1][(col * LUTX) + g];
                        end
                    end

                    // perform reduction
                    if(GATE == 0) begin // AND
                        reduce_data[row][col] = &group_reduce_data;
                    end else if(GATE == 1) begin // OR
                        reduce_data[row][col] = |group_reduce_data;
                    end else if(GATE == 2) begin // XOR
                        reduce_data[row][col] = ^group_reduce_data;
                    end else if(GATE == 3) begin // NAND
                        reduce_data[row][col] = ~&group_reduce_data;
                    end else if(GATE == 4) begin // NOR
                        reduce_data[row][col] = ~|group_reduce_data;
                    end else if(GATE == 5) begin // NXOR
                        reduce_data[row][col] = ~^group_reduce_data;
                    end else begin               // default 'x 
                        reduce_data[row][col] = 'x;
                    end
                end
            end
        end 
    end

    always@(posedge clk_i) begin
        for(int row = 1; row < STAGES; row++) begin
            reduce_data_pipeline[row] <= reduce_data[row];
        end 
    end

    assign data_o = reduce_data[STAGES][0];

endmodule