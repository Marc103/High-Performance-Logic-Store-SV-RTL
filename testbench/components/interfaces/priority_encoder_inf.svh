`ifndef PRIORITY_ENCODER_INF 
    `define PRIORITY_ENCODER_INF
interface priority_encoder_inf #(
    parameter INPUT_DATA_WIDTH,
    parameter REGISTERED_IN,
    parameter LUTX,
    parameter GRADE,

    ////////////////////////////////////////////////////////////////
    // Globally Defined Locally Set Parameters
    localparam ENCODE_GROUPS     = priority_encoder_ENCODE_GROUPS    (INPUT_DATA_WIDTH, LUTX),
    localparam ENCODE_DEPTH      = priority_encoder_ENCODE_DEPTH     (ENCODE_GROUPS),
    localparam OUTPUT_DATA_WIDTH = priority_encoder_OUTPUT_DATA_WIDTH(INPUT_DATA_WIDTH),
    localparam LATENCY           = priority_encoder_LATENCY          (
        REGISTERED_IN,
        ENCODE_DEPTH,
        max_LATENCY(1, GRADE),
        max_LATENCY(0, GRADE)
    )
) (
    input clk_i
);
    logic [INPUT_DATA_WIDTH - 1 : 0]  priority_i;
    logic [OUTPUT_DATA_WIDTH - 1 : 0] priority_encoded_o;

    // testbench sequencing signals
    logic start_sequence;
    logic end_sequence;
    logic end_last_sequence;
    logic idle;
endinterface
`endif 
