import constant_functions_pkg::*;

class FftMultiplierCoreIO #(
    parameter BASE,
    parameter EXPONENT_WIDTH,
    parameter MANTISSA_WIDTH,
    parameter LUTX,
    parameter GRADE,
    parameter REGSITERED_MULTIPLIER,
    parameter REGISTERED_NORMALIZE,
    parameter RANDOM_TRANSACTIONS = 256,
    localparam DATA_WIDTH = fft_multiplier_core_DATA_WIDTH(EXPONENT_WIDTH, MANTISSA_WIDTH),
    localparam BASE_WIDTH = alternate_base_fp_multiplier_BASE_WIDTH(BASE),
    localparam MULTIPLIER_LATENCY = alternate_base_fp_multiplier_LATENCY(
        MANTISSA_WIDTH, REGSITERED_MULTIPLIER, REGISTERED_NORMALIZE, LUTX, GRADE
    ),
    localparam LATENCY = fft_multiplier_core_LATENCY(
        MANTISSA_WIDTH, REGSITERED_MULTIPLIER, REGISTERED_NORMALIZE, LUTX, GRADE
    )
);
    // Use the existing multiplier IO/model specialization without duplicating its contract.
    typedef AlternateBaseFpMultiplierIO #(
        .BASE(BASE), .EXPONENT_WIDTH(EXPONENT_WIDTH), .MANTISSA_WIDTH(MANTISSA_WIDTH),
        .LUTX(LUTX), .GRADE(GRADE), .REGISTERED_IN(REGSITERED_MULTIPLIER),
        .REGISTERED_NORMALIZE(REGISTERED_NORMALIZE), .RANDOM_TRANSACTIONS(RANDOM_TRANSACTIONS)
    ) multiplier_io_t;
    `FFT_MULTIPLIER_CORE_IO_IN_STRUCT(DATA_WIDTH)
    `FFT_MULTIPLIER_CORE_IO_OUT_STRUCT(DATA_WIDTH)

    fft_multiplier_core_io_in_t fft_multiplier_core_io_in_q[$];
    fft_multiplier_core_io_out_t fft_multiplier_core_io_out_q[$];
    // Every item is a clock, including idle clocks: A and returning products still advance.
    bit idle[$];
    logic [7:0] error_state[$];
    logic [5:0] known_mask[$];
    logic [5:0] write_mask[$];
    logic end_last_sequence = 0;

    function new();
    endfunction
endclass
