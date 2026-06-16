`ifndef MAX_INF 
    `define MAX_INF
interface max_inf #(
    parameter DATA_WIDTH,
    parameter SIGNED,
    parameter REGISTERED_IN,
    parameter GRADE,

    ////////////////////////////////////////////////////////////////
    // Globally Defined Locally Set Parameters
    localparam LATENCY = max_LATENCY(REGISTERED_IN, GRADE)
) (
    input clk_i
);
    logic [DATA_WIDTH - 1 : 0] data_a_i;
    logic [DATA_WIDTH - 1 : 0] data_b_i;

    logic [DATA_WIDTH - 1 : 0] data_o;
    
    // testbench sequencing signals
    logic start_sequence;
    logic end_sequence;
    logic end_last_sequence;
    logic idle;
endinterface
`endif 
