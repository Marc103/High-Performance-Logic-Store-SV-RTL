`ifndef EXAMPLE_INF 
    `define EXAMPLE_INF
interface example_inf #(
    parameter DATA_WIDTH = 0
) (
    input clk_i,
    input rst_i
);
    logic [DATA_WIDTH - 1 : 0] a_i;
    logic                      valid_i;


    logic [DATA_WIDTH - 1 : 0] d_o;
    logic                      valid_o;

endinterface
`endif 