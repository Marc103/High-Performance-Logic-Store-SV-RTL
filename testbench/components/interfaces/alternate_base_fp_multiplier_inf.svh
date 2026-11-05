`ifndef ALTERNATE_BASE_FP_MULTIPLIER_INF
`define ALTERNATE_BASE_FP_MULTIPLIER_INF
import constant_functions_pkg::*;

interface alternate_base_fp_multiplier_inf #(
    parameter BASE,
    parameter EXPONENT_WIDTH,
    parameter MANTISSA_WIDTH,
    parameter LUTX,
    parameter GRADE,
    parameter REGISTERED_IN,
    parameter REGISTERED_NORMALIZE,
    localparam DATA_WIDTH = alternate_base_fp_multiplier_DATA_WIDTH(EXPONENT_WIDTH, MANTISSA_WIDTH),
    localparam BASE_WIDTH = alternate_base_fp_multiplier_BASE_WIDTH(BASE),
    localparam LATENCY = alternate_base_fp_multiplier_LATENCY(
        MANTISSA_WIDTH, REGISTERED_IN, REGISTERED_NORMALIZE, LUTX, GRADE
    )
) (input clk_i);
    logic [DATA_WIDTH - 1 : 0] a_i;
    logic [DATA_WIDTH - 1 : 0] b_i;
    logic [DATA_WIDTH - 1 : 0] product_o;
    logic start_sequence = 0;
    logic end_sequence = 0;
    logic end_last_sequence = 0;
    logic idle = 1;
endinterface
`endif
