/* 
Alternate Base FP Multiplier
- subnormal number not supported
- inputs must have zero mantissas when the exponent is zero; other encodings are undefined
- exponent-zero outputs always have zero mantissas
- uses RN-even
- Inf/Nan takes precedence over zero
- Any Inf/Nan operand preserves the combined Inf/Nan encoding

BASE [2,4,8,16...]:
- Traditional floating point uses base-2. Here we specificy a base greater or equal than 2 to
  significantly reduce logic (roughly by the factor of the log2(base)) but at the cost of
  wobbling precision which shifts the precision from 0 to -(log2(BASE) - 1). I.e a base of
  16 would cause 0 to -3 wobble in precision from the mantissa width. The chosen base
  is assumed to be a power of 2. It is recommended that the chosen base results in 
  bit groups of power of 2 (i.e base-16 is [x x x x] but base-8 is [x x x]) for conversion
  to be simpler and so that exponent bits can be trimmed without range loss/gain.

EXPONENT_WIDTH:
- The exponent bias is 2^(EXPONENT_WIDTH - 1) - 1.
- A finite nonzero value is (-1)^sign * (mantissa / 2^MANTISSA_WIDTH) * BASE^(exponent - bias).
- Exponent zero represents zero. At the maximum exponent, mantissa MSB=1 is reserved for NaN/Inf.

MANTISSA_WIDTH:
- Number of bits in the mantissa.
- Must be at least log2(BASE), so one radix digit fits in the mantissa.

REGISTERED_* [0, 1]:
- REGISTERED_IN selects the input register stage; REGISTERED_NORMALIZE selects the stage before normalization.
- The sticky OR tree can add internal register stages, with matching delays on the other fields.
  
*/

import constant_functions_pkg::*; 

module alternate_base_fp_multiplier #(
    parameter BASE,
    parameter EXPONENT_WIDTH,
    parameter MANTISSA_WIDTH,
    parameter REGISTERED_IN,
    parameter REGISTERED_NORMALIZE,

    parameter LUTX,
    parameter GRADE,


    ////////////////////////////////////////////////////////////////
    // Globally Defined Locally Set Parameters
    localparam DATA_WIDTH = alternate_base_fp_multiplier_DATA_WIDTH(EXPONENT_WIDTH, MANTISSA_WIDTH),
    localparam BASE_WIDTH = alternate_base_fp_multiplier_BASE_WIDTH(BASE),
    localparam EXPONENT_CALC_WIDTH = alternate_base_fp_multiplier_EXPONENT_CALC_WIDTH(EXPONENT_WIDTH),
    localparam EXPONENT_BIAS = alternate_base_fp_multiplier_EXPONENT_BIAS(EXPONENT_WIDTH),
    localparam EXPONENT_MAX_VALUE = alternate_base_fp_multiplier_EXPONENT_MAX_VALUE(EXPONENT_WIDTH),
    localparam STICKY_OR_WIDTH = alternate_base_fp_multiplier_STICKY_OR_WIDTH(MANTISSA_WIDTH),
    localparam STICKY_OR_GROUP_SIZE = reduction_tree_GROUP_SIZE(LUTX, GRADE),
    localparam STICKY_OR_STAGES = reduction_tree_STAGES(STICKY_OR_GROUP_SIZE, STICKY_OR_WIDTH),
    localparam STICKY_OR_LATENCY = reduction_tree_LATENCY(0, STICKY_OR_STAGES),
    localparam POST_NORMALIZE_CARRY_INDEX = alternate_base_fp_multiplier_POST_NORMALIZE_CARRY_INDEX(MANTISSA_WIDTH, BASE_WIDTH),
    localparam LATENCY = alternate_base_fp_multiplier_LATENCY(
        MANTISSA_WIDTH, REGISTERED_IN, REGISTERED_NORMALIZE, LUTX, GRADE
    )
) (
    input clk_i,
    input  [DATA_WIDTH - 1 : 0] a_i,
    input  [DATA_WIDTH - 1 : 0] b_i,
    output [DATA_WIDTH - 1 : 0] product_o
);

    logic [DATA_WIDTH - 1 : 0] a;
    logic [DATA_WIDTH - 1 : 0] b;

    logic [DATA_WIDTH - 1 : 0] a_g;
    logic [DATA_WIDTH - 1 : 0] b_g;

    always@(posedge clk_i) begin
        a <= a_i;
        b <= b_i;
    end

    assign a_g = (REGISTERED_IN == 1) ? a : a_i;
    assign b_g = (REGISTERED_IN == 1) ? b : b_i;

    logic                          a_sign_g;
    logic [EXPONENT_WIDTH - 1 : 0] a_exponent_g;
    logic [MANTISSA_WIDTH - 1 : 0] a_mantissa_g;

    logic                          b_sign_g;
    logic [EXPONENT_WIDTH - 1 : 0] b_exponent_g;
    logic [MANTISSA_WIDTH - 1 : 0] b_mantissa_g;

    assign a_sign_g     = a_g[DATA_WIDTH - 1];
    assign a_exponent_g = a_g[MANTISSA_WIDTH + EXPONENT_WIDTH - 1 : MANTISSA_WIDTH];
    assign a_mantissa_g = a_g[MANTISSA_WIDTH - 1 : 0];

    assign b_sign_g     = b_g[DATA_WIDTH - 1];
    assign b_exponent_g = b_g[MANTISSA_WIDTH + EXPONENT_WIDTH - 1 : MANTISSA_WIDTH];
    assign b_mantissa_g = b_g[MANTISSA_WIDTH - 1 : 0];

    logic inf_nan_operand;
    assign inf_nan_operand = ((&a_exponent_g) && a_mantissa_g[MANTISSA_WIDTH - 1]) ||
                             ((&b_exponent_g) && b_mantissa_g[MANTISSA_WIDTH - 1]);

    logic signed [EXPONENT_CALC_WIDTH - 1 : 0] exponent_bias;
    logic signed [EXPONENT_CALC_WIDTH - 1 : 0] a_exponent_unbiased;
    logic signed [EXPONENT_CALC_WIDTH - 1 : 0] b_exponent_unbiased;
    logic signed [EXPONENT_CALC_WIDTH - 1 : 0] exponent_sum;
    logic signed [EXPONENT_CALC_WIDTH - 1 : 0] exponent_rebiased;
    logic signed [EXPONENT_CALC_WIDTH - 1 : 0] r_exponent;
    logic zero_operand;

    always_comb begin
        // Size the integer constant bit patterns before signed arithmetic.
        exponent_bias = EXPONENT_BIAS;
        exponent_bias[EXPONENT_CALC_WIDTH - 1 : EXPONENT_WIDTH - 1] = '0;

        a_exponent_unbiased = a_exponent_g;
        a_exponent_unbiased = a_exponent_unbiased - exponent_bias;

        b_exponent_unbiased = b_exponent_g;
        b_exponent_unbiased = b_exponent_unbiased - exponent_bias;

        exponent_sum = a_exponent_unbiased + b_exponent_unbiased;
        
        exponent_rebiased = exponent_sum + exponent_bias;

        // Preserve the full exponent until normalization and final range checks.
        zero_operand = (a_exponent_g == '0) || (b_exponent_g == '0);

        if(zero_operand) begin
            r_exponent = '0;
        end else begin
            r_exponent = exponent_rebiased;
        end
    end

    logic [MANTISSA_WIDTH * 2 - 1 : 0] r_mantissa;
    assign r_mantissa = a_mantissa_g * b_mantissa_g;

    logic r_sign;
    assign r_sign = a_sign_g ^ b_sign_g;

    ////////////////////////////////////////////////////////////////
    // Normalize, Round, Post-normalize
    // Finally exponent checks happen here aswell.

    logic signed [EXPONENT_CALC_WIDTH - 1 : 0] r_exponent_reg;
    logic [MANTISSA_WIDTH * 2 - 1 : 0] r_mantissa_reg;
    logic r_sign_reg;
    logic zero_operand_reg;
    logic inf_nan_operand_reg;

    logic signed [EXPONENT_CALC_WIDTH - 1 : 0] r_exponent_g;
    logic [MANTISSA_WIDTH * 2 - 1 : 0] r_mantissa_g;
    logic r_sign_g;
    logic zero_operand_g;
    logic inf_nan_operand_g;

    always@(posedge clk_i) begin
        r_exponent_reg <= r_exponent;
        r_mantissa_reg <= r_mantissa;
        r_sign_reg <= r_sign;
        zero_operand_reg <= zero_operand;
        inf_nan_operand_reg <= inf_nan_operand;
    end

    assign r_exponent_g = (REGISTERED_NORMALIZE == 1) ? r_exponent_reg : r_exponent;
    assign r_mantissa_g = (REGISTERED_NORMALIZE == 1) ? r_mantissa_reg : r_mantissa;
    assign r_sign_g = (REGISTERED_NORMALIZE == 1) ? r_sign_reg : r_sign;
    assign zero_operand_g = (REGISTERED_NORMALIZE == 1) ? zero_operand_reg : zero_operand;
    assign inf_nan_operand_g = (REGISTERED_NORMALIZE == 1) ? inf_nan_operand_reg : inf_nan_operand;

    initial begin
        if(MANTISSA_WIDTH < BASE_WIDTH)
            $fatal(1, "MANTISSA_WIDTH must be at least BASE_WIDTH (%0d)", BASE_WIDTH);
    end

    // Normalized operand products have a nonzero radix digit in one of two groups.
    logic normalize_shift;
    logic [MANTISSA_WIDTH * 2 - 1 : 0] normalized;
    logic signed [EXPONENT_CALC_WIDTH - 1 : 0] normalized_exponent;

    assign normalize_shift = !(|r_mantissa_g[MANTISSA_WIDTH * 2 - 1 -: BASE_WIDTH]);
    assign normalized = normalize_shift ? (r_mantissa_g << BASE_WIDTH) : r_mantissa_g;

    always_comb begin
        normalized_exponent = r_exponent_g;
        if(normalize_shift && !zero_operand_g) begin
            normalized_exponent = normalized_exponent - 1;
        end
    end

    // The first discarded bit is the round bit; all lower bits form sticky.
    logic [STICKY_OR_WIDTH - 1 : 0] sticky_bits;
    logic sticky;
    generate
        if(MANTISSA_WIDTH > 1) begin : gen_sticky_bits
            assign sticky_bits = normalized[MANTISSA_WIDTH - 2 : 0];
        end else begin : gen_no_sticky_bits
            assign sticky_bits = '0;
        end
    endgenerate

    reduction_tree #(
        .DATA_WIDTH(STICKY_OR_WIDTH),
        .GATE(1),
        .REGISTERED_IN(0),
        .LUTX(LUTX),
        .GRADE(GRADE)
    ) sticky_or_tree (
        .clk_i(clk_i),
        .data_i(sticky_bits),
        .reduced_o(sticky)
    );

    logic [MANTISSA_WIDTH : 0] normalized_mantissa_round;
    logic [MANTISSA_WIDTH : 0] normalized_mantissa_round_p;
    logic signed [EXPONENT_CALC_WIDTH - 1 : 0] normalized_exponent_p;
    logic r_sign_p;
    logic zero_operand_p;
    logic inf_nan_operand_p;

    assign normalized_mantissa_round = normalized[MANTISSA_WIDTH * 2 - 1 : MANTISSA_WIDTH - 1];

    pipe #(.DATA_WIDTH(MANTISSA_WIDTH + 1), .LATENCY(STICKY_OR_LATENCY)) normalized_mantissa_round_pipe (
        .clk_i(clk_i), .data_i(normalized_mantissa_round), .data_o(normalized_mantissa_round_p)
    );
    pipe #(.DATA_WIDTH(EXPONENT_CALC_WIDTH), .LATENCY(STICKY_OR_LATENCY)) normalized_exponent_pipe (
        .clk_i(clk_i), .data_i(normalized_exponent), .data_o(normalized_exponent_p)
    );
    pipe #(.DATA_WIDTH(1), .LATENCY(STICKY_OR_LATENCY)) r_sign_pipe (
        .clk_i(clk_i), .data_i(r_sign_g), .data_o(r_sign_p)
    );
    pipe #(.DATA_WIDTH(1), .LATENCY(STICKY_OR_LATENCY)) zero_operand_pipe (
        .clk_i(clk_i), .data_i(zero_operand_g), .data_o(zero_operand_p)
    );
    pipe #(.DATA_WIDTH(1), .LATENCY(STICKY_OR_LATENCY)) inf_nan_operand_pipe (
        .clk_i(clk_i), .data_i(inf_nan_operand_g), .data_o(inf_nan_operand_p)
    );

    logic round;
    logic lsb;
    logic increment;
    logic [MANTISSA_WIDTH : 0] normalized_rounded;
    logic carry;
    logic [MANTISSA_WIDTH - 1 : 0] post_normalized_mantissa;
    logic signed [EXPONENT_CALC_WIDTH - 1 : 0] post_normalized_exponent;

    assign round = normalized_mantissa_round_p[0];
    assign lsb = normalized_mantissa_round_p[1];
    assign increment = round & (sticky | lsb);

    always_comb begin
        normalized_rounded = '0;
        normalized_rounded[MANTISSA_WIDTH - 1 : 0] = normalized_mantissa_round_p[MANTISSA_WIDTH : 1];
        normalized_rounded = normalized_rounded + increment;
    end

    assign carry = normalized_rounded[MANTISSA_WIDTH];

    always_comb begin
        // On carry, all retained bits are zero; insert its radix-shifted bit.
        post_normalized_mantissa = normalized_rounded[MANTISSA_WIDTH - 1 : 0];
        post_normalized_mantissa[POST_NORMALIZE_CARRY_INDEX] = post_normalized_mantissa[POST_NORMALIZE_CARRY_INDEX] | carry;
        post_normalized_exponent = normalized_exponent_p;
        if(carry && !zero_operand_p) begin
            post_normalized_exponent = post_normalized_exponent + 1;
        end
    end

    // Classify the final exponent after both normalization and rounding carry.
    logic signed [EXPONENT_CALC_WIDTH - 1 : 0] exponent_max_value;
    logic exponent_overflow;
    logic exponent_underflow;
    logic final_sign;
    logic [EXPONENT_WIDTH - 1 : 0] final_exponent;
    logic [MANTISSA_WIDTH - 1 : 0] final_mantissa;

    always_comb begin
        exponent_max_value = EXPONENT_MAX_VALUE;
        exponent_max_value[EXPONENT_CALC_WIDTH - 1 : EXPONENT_WIDTH] = '0;

        exponent_overflow = !zero_operand_p &&
            ((post_normalized_exponent > exponent_max_value) ||
             ((post_normalized_exponent == exponent_max_value) && post_normalized_mantissa[MANTISSA_WIDTH - 1]));
        exponent_underflow = !zero_operand_p && (post_normalized_exponent <= 0);

        final_sign = r_sign_p;
        final_exponent = post_normalized_exponent[EXPONENT_WIDTH - 1 : 0];
        final_mantissa = post_normalized_mantissa;

        // An input NaN/Inf overrides zero and ordinary range classification.
        if(inf_nan_operand_p) begin
            final_exponent = '1;
            final_mantissa[MANTISSA_WIDTH - 1] = 1;
        end else if(zero_operand_p) begin
            final_exponent = '0;
            final_mantissa = '0;
        end else if(exponent_underflow) begin
            final_exponent = '0;
            final_mantissa = '0;
        end else if(exponent_overflow) begin
            final_exponent = '1;
            final_mantissa[MANTISSA_WIDTH - 1] = 1;
        end
        if(final_exponent == '0) begin
            final_mantissa = '0;
        end
    end

    assign product_o = {final_sign, final_exponent, final_mantissa};

endmodule
