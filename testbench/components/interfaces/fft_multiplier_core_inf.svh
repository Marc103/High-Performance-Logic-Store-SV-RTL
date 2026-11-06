`ifndef FFT_MULTIPLIER_CORE_INF
`define FFT_MULTIPLIER_CORE_INF
import constant_functions_pkg::*;

interface fft_multiplier_core_inf #(
    parameter BASE,
    parameter EXPONENT_WIDTH,
    parameter MANTISSA_WIDTH,
    parameter LUTX,
    parameter GRADE,
    parameter REGISTERED_IN,
    parameter REGISTERED_NORMALIZE,
    localparam DATA_WIDTH = fft_multiplier_core_DATA_WIDTH(EXPONENT_WIDTH, MANTISSA_WIDTH),
    localparam BASE_WIDTH = alternate_base_fp_multiplier_BASE_WIDTH(BASE),
    localparam MULTIPLIER_LATENCY = alternate_base_fp_multiplier_LATENCY(
        MANTISSA_WIDTH, REGISTERED_IN, REGISTERED_NORMALIZE, LUTX, GRADE
    ),
    localparam LATENCY = fft_multiplier_core_LATENCY(
        MANTISSA_WIDTH, REGISTERED_IN, REGISTERED_NORMALIZE, LUTX, GRADE
    )
) (input clk_i);
    logic rst_i = 1;
    logic w_b_valid_i = 0;
    logic [DATA_WIDTH - 1 : 0] wr_i = '0, wi_i = '0, br_i = '0, bi_i = '0;
    logic [DATA_WIDTH - 1 : 0] ar_i = '0, ai_i = '0;
    logic [DATA_WIDTH - 1 : 0] wrbr_o, wibi_o, wrbi_o, wibr_o, ar_o, ai_o;
    logic valid_o;
    logic start_sequence = 0;
    logic end_sequence = 0;
    logic end_last_sequence = 0;
    logic idle = 1;
endinterface
`endif
