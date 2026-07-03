/*
Multistage Mux
Fully customizable mux circuit.

DATA_WIDTH:
- Data width.

SIZE:
- Number of elements to be mux'ed

REGISTERED_IN [0, 1]:
- If 1, inputs are registered, increasing latency by 1 cycle,
  else, inputs are direct.

LUTX [1, ...]:
- Size of primitive LUTs and should be set to the primitive LUT size of FPGA.
  It is use to determine the base mux capability. E.e a LUT3 can perform a 2:1
  mux in one step since we require 1 selectors, 2 inputs. Same with a LUT4 and
  LUT5 but then LUT6 unlocks 4:1 mux... then the next big jump would be a LUT11
  for a 8:1. Set this to your FPGA primitive. Rather than increasing this value
  if lower latency is required, instead see GRADE.

GRADE [1, ...]:
- The grade tells us the logic depth allowed per stage. I.e with LUTX set to 6 and
GRADE set to 1, we will reduce the input at each layer by a 4:1 mux. However, if 
GRADE is set to 2 instead, this will allows us to do 4:1 -> 4:1, effectively 16:1
in one step (2 logic depths). You could also artificially adjust the LUTX to something
like 11 but it will no longer be consistent with the grading system and so is not
advisable.
*/

import constant_functions_pkg::*; 

module multistage_mux #(
    parameter DATA_WIDTH,
    parameter SIZE,
    parameter REGISTERED_IN,
    parameter LUTX,
    parameter GRADE,

    ////////////////////////////////////////////////////////////////
    // Globally Defined Locally Set Parameters
    localparam                                      SELECTOR_WIDTH       = multistage_mux_SELECTOR_WIDTH(SIZE),
    localparam                                      GROUP_SELECTOR_WIDTH = multistage_mux_GROUP_SELECTOR_WIDTH(LUTX, GRADE),
    localparam                                      GROUP_SIZE           = multistage_mux_GROUP_SIZE(GROUP_SELECTOR_WIDTH),
    localparam                                      STAGES               = multistage_mux_STAGES(GROUP_SIZE, SIZE),
    localparam int_t [SMALL - 1 : 0][SOLAR - 1 : 0] MUX_TREE_MAP         = multistage_mux_MUX_TREE_MAP(STAGES, GROUP_SIZE, SIZE),
    localparam                                      LATENCY              = multistage_mux_LATENCY(REGISTERED_IN, STAGES)
) (
    input clk_i,

    input [SIZE - 1 : 0][DATA_WIDTH - 1 : 0]     data_i,
    input               [SELECTOR_WIDTH - 1 : 0] sel_i,

    output              [DATA_WIDTH - 1 : 0] data_o
);

    logic [SIZE - 1 : 0][DATA_WIDTH - 1 : 0] data;
    logic [SIZE - 1 : 0][DATA_WIDTH - 1 : 0] data_g;

    logic [SELECTOR_WIDTH - 1 : 0] sel;
    logic [SELECTOR_WIDTH - 1 : 0] sel_g;

    always@(posedge clk_i) begin
        data <= data_i;
        sel  <= sel_i;
    end

    assign data_g = (REGISTERED_IN == 1) ? data : data_i;
    assign sel_g  = (REGISTERED_IN == 1) ? sel : sel_i;

    
    // seperating it like this allows us to refer directly a combinational result
    // instead of just registered result
    logic [STAGES : 0][SIZE - 1 : 0][DATA_WIDTH - 1 : 0] mux_data;
    logic [STAGES - 1 : 0][SIZE - 1 : 0][DATA_WIDTH - 1 : 0] mux_data_pipeline;
    
    logic [STAGES - 1 : 0][SELECTOR_WIDTH - 1 : 0] sel_pipeline;
    
    /*
    So whilst I could have created another 'mux' module, it would be too modular in the sense that
    it would be circular in defintion. Meaning, a multistage_mux can be configured just as a simpler
    less parameterized 'mux', hence we do the hard work here in the always_comb block.

    Flow is:

        mux_data_pipeline[row-1]..  -----|
                                         |
                                         |
                                         V
        mux_data_pipeline[row]... <----- mux_data[row]...    
        |                                |
        |                                |
        V                                V
        represents                  represents
        registered                  combinational
        output at that              output at that
        stage                       stage
    */
    
    always_comb begin
        mux_data[0]          = 'x;

        for(int row = 1; row <= STAGES; row++) begin
            for(int col = 0; col < SIZE; col++) begin
                if(MUX_TREE_MAP[row][col] != 0) begin
                    logic [GROUP_SIZE - 1 : 0][DATA_WIDTH - 1 : 0]           group_mux_data;
                    logic                     [GROUP_SELECTOR_WIDTH - 1 : 0] sel;

                    // wire inputs, bits are set to 'x to fill partial groups
                    group_mux_data = 'x;
                    for(int g = 0; g < MUX_TREE_MAP[row - 1][col * GROUP_SIZE]; g++) begin
                        if(row == 1) begin
                            group_mux_data[g] = data_g[(col * GROUP_SIZE) + g];
                        end else begin
                            group_mux_data[g] = mux_data_pipeline[row - 1][(col * GROUP_SIZE) + g];
                        end
                    end

                    // wire selector, bits are set to 0 to fill partial sel
                    sel = '0;
                    for (int s = 0; s < GROUP_SELECTOR_WIDTH; s++) begin
                        if (((row - 1) * GROUP_SELECTOR_WIDTH + s) < SELECTOR_WIDTH) begin
                            if(row == 1) begin
                                sel[s] = sel_g[(row - 1) * GROUP_SELECTOR_WIDTH + s];
                            end else begin
                                sel[s] = sel_pipeline[row - 1][(row - 1) * GROUP_SELECTOR_WIDTH + s];
                            end
                        end
                    end

                    // perform actual mux
                    mux_data[row][col] = group_mux_data[sel];
                end
            end
        end 
    end

    always@(posedge clk_i) begin
        for(int row = 1; row < STAGES; row++) begin
            mux_data_pipeline[row] <= mux_data[row];
            if(row == 1) begin
                sel_pipeline[row] <= sel_g;
            end else begin
                sel_pipeline[row] <= sel_pipeline[row - 1];
            end 
        end 
    end

    assign data_o = mux_data[STAGES][0];

endmodule
