/*
Equal
Compares if two inputs are equal. Two or one stage pipeline (as indicated by GRADE)
where a compare (addition) then mux happens.

DATA_WIDTH:
- Data width.

REGISTERED_IN [0, 1]:
- If 1, inputs are registered, increasing latency by 1 cycle,
  else, inputs are direct.

GRADE [1,2]:
- Determines logic levels per stage. If 1, the compare and mux happen in
  separate stages (since 1 logic level per stage), which is 2 cycles of latency. 
  If 2, compare and mux happen in 1 stage (2 logic levels per stage), using 1 cycles of latency.
*/
import constant_functions_pkg::*; 

module equal #(
    parameter DATA_WIDTH,
    parameter REGISTERED_IN,
    parameter GRADE,

    ////////////////////////////////////////////////////////////////
    // Globally Defined Locally Set Parameters
    localparam LATENCY = equal_LATENCY(REGISTERED_IN, GRADE)
) (
    input clk_i

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

    logic unsigned [DATA_WIDTH - 1 : 0] data_a_g_u;
    logic unsigned [DATA_WIDTH - 1 : 0] data_b_g_u;
    
    assign data_a_g_u = data_a_g[DATA_WIDTH - 1 : 0];
    assign data_b_g_u = data_b_g[DATA_WIDTH - 1 : 0];

    logic [1:0] c0;
    logic [1:0] c1;

    logic [1:0] d0;
    logic [1:0] d1;

    assign c0 = data_a_g_u < data_b_g_u;
    assign c1 = data_a_g_u > data_b_g_u;

    always@(posedge clk_i) begin
        d0 <= c0;
        d1 <= c1;
    end

    logic eq;
    always_comb begin
        if(GRADE == 1) begin
            eq = !(c0 & c1);
        end else if(GRADE == 2) begin
            eq = !(d0 & d1);
        end else begin // assume GRADE = 2
            eq = !(d0 & d1);
        end
    end

    assign eq_o = eq;
endmodule
