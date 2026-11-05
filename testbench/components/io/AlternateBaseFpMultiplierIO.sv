import constant_functions_pkg::*;

class AlternateBaseFpMultiplierIO #(
    parameter BASE,
    parameter EXPONENT_WIDTH,
    parameter MANTISSA_WIDTH,
    parameter LUTX,
    parameter GRADE,
    parameter REGISTERED_IN,
    parameter REGISTERED_NORMALIZE,
    parameter RANDOM_TRANSACTIONS = 256,
    localparam DATA_WIDTH = alternate_base_fp_multiplier_DATA_WIDTH(EXPONENT_WIDTH, MANTISSA_WIDTH),
    localparam BASE_WIDTH = alternate_base_fp_multiplier_BASE_WIDTH(BASE),
    localparam LATENCY = alternate_base_fp_multiplier_LATENCY(
        MANTISSA_WIDTH, REGISTERED_IN, REGISTERED_NORMALIZE, LUTX, GRADE
    ),
    localparam MODEL_PRODUCT_WIDTH = 2 * MANTISSA_WIDTH + 1,
    localparam MODEL_EXPONENT_WIDTH = EXPONENT_WIDTH + 3
);
    `ALTERNATE_BASE_FP_MULTIPLIER_IO_IN_STRUCT(DATA_WIDTH)
    `ALTERNATE_BASE_FP_MULTIPLIER_IO_OUT_STRUCT(DATA_WIDTH)

    alternate_base_fp_multiplier_io_in_t alternate_base_fp_multiplier_io_in_q[$];
    alternate_base_fp_multiplier_io_out_t alternate_base_fp_multiplier_io_out_q[$];
    bit idle[$];
    logic [7:0] error_state[$];
    logic end_last_sequence = 0;

    function new();
    endfunction
endclass
