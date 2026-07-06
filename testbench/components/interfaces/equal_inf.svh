`ifndef EQUAL_INF
    `define EQUAL_INF
interface equal_inf #(
    parameter DATA_WIDTH,
    parameter REGISTERED_IN,
    parameter GRADE,

    ////////////////////////////////////////////////////////////////
    // Globally Defined Locally Set Parameters
    localparam LATENCY = equal_LATENCY(REGISTERED_IN, GRADE)
) (
    input clk_i
);
    logic [DATA_WIDTH - 1 : 0] data_a_i;
    logic [DATA_WIDTH - 1 : 0] data_b_i;

    logic eq_o;
    
    // testbench sequencing signals
    logic start_sequence;
    logic end_sequence;
    logic end_last_sequence;
    logic idle;
endinterface
`endif
