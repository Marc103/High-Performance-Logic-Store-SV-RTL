/* 
A 4-stage pipelined alternate base floating point adder with customizable exponent
and mantissa widths, inspired by the IBM hexadecimal floating point and necesitated
by the need to make compute cheap. Tradeoff is loss in precision due to wobbling
precision and inability to use implicit leading bit. Base selected must be a power
of 2.

Keep MANT_WIDTH / log2(BASE) < 4, to ensure that our largest muxes are 4:1, which fit 
perfectly into LUT6. 

Subnormal numbers are not supported, meaning exponent underflow simply results in 0. 

Because we are using a base greater than 2, we cannot assume an implicit leading 1 
bit in the mantissa, so the precision is MANT_WIDTH bits not MANT_WIDTH + 1 as in 
traditional floating point.

NaNs and Infs are represented with the largest exponent value and RN-even exact rounding 
as per the standard.

BASE [4,8,16...]:
- Traditional floating point uses base-2. Here we specificy a base greater than 2 to
  significantly reduce logic (roughly by the factor of the log2(base)) but at the cost of
  wobbling precision which shifts the precision from 0 to -(BASE - 1). I.e a base of
  16 would cause 0 to -3 wobble in precision from the mantissa width. The chosen base
  is assumed to be a power of 2. It is recommended that the chosen base results in 
  bit groups of power of 2 (i.e base-16 is [x x x x] but base-8 is [x x x]) for conversion
  to be simpler and so that exponent bits can be trimmed without range loss/gain.

EXP_WIDTH:
- Specifies the width of the exponent field, which determines the range of representable numbers. Effective range is:
  -BASE^(2^(EXP_WIDTH-1)) * 2 <--> BASE^(2^(EXP_WIDTH-1)) 
  (there is a slightly more precise formula for the upper bound but this is good enough)

  The exponent offset is 2^(EXP_WIDTH - 1) - 1.

MANT_WIDTH:
- Number of bits in the mantissa.

PIPE_REG_0 to PIPE_REG_3 [0, 1]:
- Pipeline registers can be turned on/off with parameters PIPE_REG_0 to PIPE_REG_3, corresponding to the 4 stages of the pipeline.
  The pipeline registers are at the start of each stage.

Hexadecimal FP16 example:

BASE = 16, EXP_WIDTH = 3, MANT_WIDTH = 12

[sign bit][3 exponent bits][12 mantissa bits]

Precision is 12-9 bits or about 2.5 - 3.5 decimal digits.

Range is -16^(2^(3-1)) * 2 <--> 16^(2^(3-1)) 
               0.0000305.. <--> ~65536 (a little less, technically 2^15 * (1 + 4095/4096) = 65528)

Exponent bias offset is 2^(3-1) - 1 = 3

Some Additional information (implementation details):
guard bits - G_BASE-1 to G_0
[sign bit][exponent bits][mantissa bits][G_BASE-1, G_BASE-2, ..., G_0][round bit][sticky bit]

Inf/Nan is detected as &(exponent bits) & (MSB of mantissa bits) 
*/

import constant_functions_pkg::*; 

module alternate_base_fp_adder #(
    parameter BASE,
    parameter EXP_WIDTH,
    parameter MANT_WIDTH,
    parameter PIPE_REG_0,
    parameter PIPE_REG_1,
    parameter PIPE_REG_2,
    parameter PIPE_REG_3

    ////////////////////////////////////////////////////////////////
    // Globally Defined Locally Set Parameters
    localparam DATA_WIDTH = alternate_base_fp_DATA_WIDTH(EXP_WIDTH, MANT_WIDTH),
    localparam LATENCY    = alternate_base_fp_LATENCY   (PIPE_REG_0, PIPE_REG_1, PIPE_REG_2, PIPE_REG_3)
) (
    input  [DATA_WIDTH - 1 : 0] a_i,
    input  [DATA_WIDTH - 1 : 0] b_i,
    output [DATA_WIDTH - 1 : 0] sum_o
);
    // this is just a placeholder for now, will implement the actual adder later
    assign sum_o = a_i + b_i;

endmodule


// Stage 1
/*
Determine amount to shift based on exponent difference and shift mantissa accordingly.
Rather than swapping according to magnitude order, its better for packing on FPGAs to 
infer a shifter for each side under the assumption that the MANT_WIDTH/log2(BASE) < 4 
so that the shifters are at most 4:1 muxes which fit perfectly into LUT6.
*/
module stage_1 #(
    parameter BASE,
    parameter EXP_WIDTH,
    parameter MANT_WIDTH,
    parameter PIPE_REG_0,

    ////////////////////////////////////////////////////////////////
    // Globally Defined Locally Set Parameters
    localparam BASE_WIDTH       = alternate_base_fp_BASE_WIDTH      (BASE),
    localparam STICKY_WIDTH     = alternate_base_fp_STICKY_WIDTH    (MANT_WIDTH, BASE_WIDTH),
    localparam DATA_WIDTH_EXT_0 = alternate_base_fp_DATA_WIDTH_EXT_0(EXP_WIDTH, MANT_WIDTH, BASE_WIDTH, STICKY_WIDTH),
    localparam DATA_WIDTH_EXT_1 = alternate_base_fp_DATA_WIDTH_EXT_1(EXP_WIDTH, MANT_WIDTH, BASE_WIDTH)
) (
    input  [DATA_WIDTH - 1 : 0] a_i,
    input  [DATA_WIDTH - 1 : 0] b_i,
    output [DATA_WIDTH_EXT_1 - 1 : 0] a_aligned_o,
    output [DATA_WIDTH_EXT_1 - 1 : 0] b_aligned_o
)

endmodule