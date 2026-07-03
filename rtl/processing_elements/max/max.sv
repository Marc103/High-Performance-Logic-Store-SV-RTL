/*
Max
Compares two inputs, signed or unsigned (as indicated by SIGNED)
and returns the greater than one else the other (in effect, greater
than or equal). Two or one stage pipeline (as indicated by GRADE)
where a compare (addition) then mux happens.

DATA_WIDTH:
- Data width.

SIGNED [0, 1]:
- should the input be treated as signed? 1 - yes, 0 - no

REGISTERED_IN [0, 1]:
- If 1, inputs are registered, increasing latency by 1 cycle,
  else, inputs are direct.

GRADE [1,2]:
- Determines logic levels per stage. If 1, the compare and mux happen in
  separate stages (since 1 logic level per stage), which is 2 cycles of latency. 
  If 2, compare and mux happen in 1 stage (2 logic levels per stage), using 1 cycles of latency.
*/

import constant_functions_pkg::*; 

module max #(
    parameter DATA_WIDTH,
    parameter SIGNED,
    parameter REGISTERED_IN,
    parameter GRADE,

    ////////////////////////////////////////////////////////////////
    // Globally Defined Locally Set Parameters
    localparam LATENCY = max_LATENCY(REGISTERED_IN, GRADE)
) (
    input clk_i,

    input [DATA_WIDTH - 1 : 0] data_a_i,
    input [DATA_WIDTH - 1 : 0] data_b_i,

    output [DATA_WIDTH - 1 : 0] data_o
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

    logic unsigned [DATA_WIDTH - 1 : 0] data_a_us_g;
    logic unsigned [DATA_WIDTH - 1 : 0] data_b_us_g;
    logic unsigned [2:0][DATA_WIDTH - 1 : 0] data_a_us;
    logic unsigned [2:0][DATA_WIDTH - 1 : 0] data_b_us;

    logic signed [DATA_WIDTH - 1 : 0] data_a_s;
    logic signed [DATA_WIDTH - 1 : 0] data_b_s;

    logic mux_sel_g;
    logic [1:0] mux_sel;

    always_comb begin
        data_a_us_g = data_a_g[DATA_WIDTH - 1 : 0];
        data_b_us_g = data_b_g[DATA_WIDTH - 1 : 0];

        data_a_s = data_a_g[DATA_WIDTH - 1 : 0];
        data_b_s = data_b_g[DATA_WIDTH - 1 : 0];

        if(SIGNED == 1) begin
            mux_sel_g = data_b_s < data_a_s ? 1 : 0;
        end else begin
            mux_sel_g = data_b_us_g < data_a_us_g ? 1 : 0;
        end
    end

    always@(posedge clk_i) begin
        if(GRADE == 1) begin
            data_a_us[1] <= data_a_us_g;
            data_b_us[1] <= data_b_us_g;

            data_a_us[2] <= mux_sel[1] ? data_a_us[1] : data_b_us[1];
        end else if(GRADE == 2) begin
            data_a_us[1] <= mux_sel_g ? data_a_us_g : data_b_us_g;
        end else begin
            data_a_us[1] <= mux_sel_g ? data_a_us_g : data_b_us_g;
        end
        mux_sel[1] <= mux_sel_g;
    end

    generate 
        if(GRADE == 1) begin
            assign data_o = data_a_us[2];
        end else if(GRADE == 2) begin
            assign data_o = data_a_us[1];
        end else begin
            assign data_o = data_a_us[1];
        end
    endgenerate

endmodule
