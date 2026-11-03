`ifndef ALTERNATE_BASE_FP_ADDER_INF
`define ALTERNATE_BASE_FP_ADDER_INF
import constant_functions_pkg::*;

interface alternate_base_fp_adder_inf #(
    parameter BASE,
    parameter EXPONENT_WIDTH,
    parameter MANTISSA_WIDTH,
    parameter LUTX,
    parameter GRADE,
    parameter REGISTERED_SWAP_IN,
    parameter REGISTERED_SWAP_MUX,
    parameter REGISTERED_ALIGN_STICKY_IN,
    parameter REGISTERED_ALIGN_EXPONENT_MUX,
    parameter REGISTERED_ALIGN_MUX,
    parameter REGISTERED_ADD_CONVERT,
    parameter REGISTERED_ADD_CONVERT_CONVERT,
    parameter REGISTERED_PRIORITY_ENCODE,
    parameter REGISTERED_PRIORITY_ENCODE_ENCODER,
    parameter REGISTERED_NORMALIZE_ROUND_POST_NORMALIZE,
    parameter REGISTERED_NORMALIZE_ROUND_POST_NORMALIZE_ROUND,
    localparam DATA_WIDTH = alternate_base_fp_adder_DATA_WIDTH(EXPONENT_WIDTH, MANTISSA_WIDTH),
    localparam BASE_WIDTH = alternate_base_fp_adder_BASE_WIDTH(BASE),
    localparam NORMALIZE_CHOICES = alternate_base_fp_adder_NORMALIZE_CHOICES(BASE_WIDTH, MANTISSA_WIDTH),
    localparam PRIORITY_ENCODER_SELECTOR_WIDTH = priority_encoder_OUTPUT_DATA_WIDTH(NORMALIZE_CHOICES),
    localparam LATENCY = alternate_base_fp_adder_LATENCY(
        BASE,
        MANTISSA_WIDTH,
        LUTX,
        GRADE,
        REGISTERED_SWAP_IN,
        REGISTERED_SWAP_MUX,
        REGISTERED_ALIGN_STICKY_IN,
        REGISTERED_ALIGN_EXPONENT_MUX,
        REGISTERED_ALIGN_MUX,
        REGISTERED_ADD_CONVERT,
        REGISTERED_ADD_CONVERT_CONVERT,
        REGISTERED_PRIORITY_ENCODE,
        REGISTERED_PRIORITY_ENCODE_ENCODER,
        REGISTERED_NORMALIZE_ROUND_POST_NORMALIZE,
        REGISTERED_NORMALIZE_ROUND_POST_NORMALIZE_ROUND
    )
) (input clk_i);
    logic [DATA_WIDTH - 1 : 0] a_i;
    logic [DATA_WIDTH - 1 : 0] b_i;
    logic [DATA_WIDTH - 1 : 0] sum_o;
    logic start_sequence = 0;
    logic end_sequence = 0;
    logic end_last_sequence = 0;
    logic idle = 1;
endinterface
`endif
