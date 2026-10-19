/* 
A 4-stage pipelined alternate base floating point adder with customizable exponent
and mantissa widths, inspired by the IBM hexadecimal floating point and necesitated
by the need to make compute cheap. Tradeoff is loss in precision due to wobbling
precision and inability to use implicit leading bit. Base selected must be a power
of 2.

Keep MANTISSA_WIDTH / log2(BASE) < 4, to ensure that our largest muxes are 4:1, which fit 
perfectly into LUT6. 

Subnormal numbers are not supported, meaning exponent underflow simply results in 0. 

Because we are using a base greater than 2, we cannot assume an implicit leading 1 
bit in the mantissa, so the precision is MANTISSA_WIDTH bits not MANTISSA_WIDTH + 1 as in 
traditional floating point.

NaNs and Infs are represented with the largest exponent value and RN-even exact rounding 
as per the standard.

BASE [4,8,16...]:
- Traditional floating point uses base-2. Here we specificy a base greater or equal than 2 to
  significantly reduce logic (roughly by the factor of the log2(base)) but at the cost of
  wobbling precision which shifts the precision from 0 to -(BASE - 1). I.e a base of
  16 would cause 0 to -3 wobble in precision from the mantissa width. The chosen base
  is assumed to be a power of 2. It is recommended that the chosen base results in 
  bit groups of power of 2 (i.e base-16 is [x x x x] but base-8 is [x x x]) for conversion
  to be simpler and so that exponent bits can be trimmed without range loss/gain.

EXPONENT_WIDTH:
- Specifies the width of the exponent field, which determines the range of representable numbers. Effective range is:
  -BASE^(2^(EXPONENT_WIDTH-1)) * 2 <--> BASE^(2^(EXPONENT_WIDTH-1)) 
  (there is a slightly more precise formula for the upper bound but this is good enough)

  The exponent offset is 2^(EXPONENT_WIDTH - 1) - 1.

MANTISSA_WIDTH:
- Number of bits in the mantissa.

REGISTERED_IN_* [0, 1]:
- Pipeline registers can be turned on/off with parameters REGISTERED_IN_*, corresponding to the 4 stages of the pipeline.
  The pipeline registers are at the start of each stage.

Hexadecimal FP16 example:

BASE = 16, EXPONENT_WIDTH = 3, MANTISSA_WIDTH = 12

[sign bit][3 exponent bits][12 mantissa bits]

Precision is 12-9 bits or about 2.5 - 3.5 decimal digits.

Range is -16^(2^(3-1)) * 2 <--> 16^(2^(3-1)) 
               0.0000305.. <--> ~65536 (a little less, technically 2^15 * (1 + 4095/4096) = 65528)

Exponent bias offset is 2^(3-1) - 1 = 3

Some Additional information (implementation details):
[sign bit][exponent bits][mantissa bits][guard bit][round bit][sticky bit]

Back to Hexadecimal FP16 example, what the sticky bit needs to be computed:
[x x x x][x x x x][x x x x][G G G G  R S]
[0 0 0 0][0 0 0 0][0 0 0 0][x x x x][x x x x][x x x x] | No need for more bits here.
Sticky bit is MANTISSA_WIDTH - log2(BASE) - 1 bits OR reduction tree.

After addition, left shift assume endless 0 from the left of the sticky bit
and consumes the guard bits. 
(what was it, a arithmetic or logical shift again?).

Right shift is more interesting, round is replaced by the shifted value and
S remains as S prior to right shift.

[1][x x x x][x x x x][x x x x][G G G G  R S]

   [0 0 0 1][x x x x][x x x x][Rnew S]

Can a right shift followed by a round operation then cause another left shift?
Can a 3-bit + 3-bit give 1111? 111 + 111 = 1110, safe.


Inf/Nan is detected as &(exponent bits) & (MSB of mantissa bits) 
*/

import constant_functions_pkg::*; 

module alternate_base_fp_adder #(
    parameter BASE,
    parameter EXPONENT_WIDTH,
    parameter MANTISSA_WIDTH,

    parameter LUTX,
    parameter GRADE,


    ////////////////////////////////////////////////////////////////
    // Globally Defined Locally Set Parameters
    localparam DATA_WIDTH = alternate_base_fp_DATA_WIDTH(EXPONENT_WIDTH, MANTISSA_WIDTH),
    localparam LATENCY    = alternate_base_fp_LATENCY   (PIPE_REG_0, PIPE_REG_1, PIPE_REG_2, PIPE_REG_3)
) (
    input  [DATA_WIDTH - 1 : 0] a_i,
    input  [DATA_WIDTH - 1 : 0] b_i,
    output [DATA_WIDTH - 1 : 0] sum_o
);
    // this is just a placeholder for now, will implement the actual adder later
    //
    assign sum_o = a_i + b_i;

endmodule

// Swapper
/*
Swap 'a' with 'b' if 'b' has a higher exponent.
*/
module abfp_swapper #(
    parameter BASE,
    parameter EXPONENT_WIDTH,
    parameter MANTISSA_WIDTH,
    parameter REGISTERED_IN,
    parameter REGISTERED_MUX

    ////////////////////////////////////////////////////////////////
    // Globally Defined Locally Set Parameters 
) (
    input clk_i,

    input                           a_sign_i,
    input  [EXPONENT_WIDTH - 1 : 0] a_exponent_i,
    input  [MANTISSA_WIDTH - 1 : 0] a_mantissa_i,

    input                           b_sign_i,
    input  [EXPONENT_WIDTH - 1 : 0] b_exponent_i,
    input  [MANTISSA_WIDTH - 1 : 0] b_mantissa_i,

    output                          a_swap_sign_o,
    output [EXPONENT_WIDTH - 1 : 0] a_swap_exponent_o,
    output [MANTISSA_WIDTH - 1 : 0] a_swap_mantissa_o,

    output                          b_swap_sign_o,
    output [EXPONENT_WIDTH - 1 : 0] b_swap_exponent_o,
    output [MANTISSA_WIDTH - 1 : 0] b_swap_mantissa_o,
);

    logic                           a_sign;
    logic  [EXPONENT_WIDTH - 1 : 0] a_exponent;
    logic  [MANTISSA_WIDTH - 1 : 0] a_mantissa;

    logic                           a_sign_g;
    logic  [EXPONENT_WIDTH - 1 : 0] a_exponent_g;
    logic  [MANTISSA_WIDTH - 1 : 0] a_mantissa_g;

    logic                           b_sign;
    logic  [EXPONENT_WIDTH - 1 : 0] b_exponent;
    logic  [MANTISSA_WIDTH - 1 : 0] b_mantissa;

    logic                           b_sign_g;
    logic  [EXPONENT_WIDTH - 1 : 0] b_exponent_g;
    logic  [MANTISSA_WIDTH - 1 : 0] b_mantissa_g;

    always@(posedge clk_i) begin
        a_sign     <= a_sign_i;
        a_exponent <= a_exponent_i;
        a_mantissa <= a_mantissa_i;

        b_sign     <= b_sign_i;
        b_exponent <= b_exponent_i;
        b_mantissa <= b_mantissa_i;
    end

    assign a_sign_g     = (REGISTERED_IN == 1) ? a_sign     : a_sign_i;
    assign a_exponent_g = (REGISTERED_IN == 1) ? a_exponent : a_exponent_i;
    assign a_mantissa_g = (REGISTERED_IN == 1) ? a_mantissa : a_mantissa_i;

    assign b_sign_g     = (REGISTERED_IN == 1) ? b_sign     : b_sign_i;
    assign b_exponent_g = (REGISTERED_IN == 1) ? b_exponent : b_exponent_i;
    assign b_mantissa_g = (REGISTERED_IN == 1) ? b_mantissa : b_mantissa_i;

    logic                           a_sign_p;
    logic  [EXPONENT_WIDTH - 1 : 0] a_exponent_p;
    logic  [MANTISSA_WIDTH - 1 : 0] a_mantissa_p;

    logic                           b_sign_p;
    logic  [EXPONENT_WIDTH - 1 : 0] b_exponent_p;
    logic  [MANTISSA_WIDTH - 1 : 0] b_mantissa_p;

    pipe #(.DATA_WIDTH(1),              .LATENCY(REGISTERED_MUX)) a_sign_pipe     (.clk_i(clk_i), .data_i(a_sign_g),     .data_o(a_sign_p));
    pipe #(.DATA_WIDTH(EXPONENT_WIDTH), .LATENCY(REGISTERED_MUX)) a_exponent_pipe (.clk_i(clk_i), .data_i(a_exponent_g), .data_o(a_exponent_p));
    pipe #(.DATA_WIDTH(MANTISSA_WIDTH), .LATENCY(REGISTERED_MUX)) a_mantissa_pipe (.clk_i(clk_i), .data_i(a_mantissa_g), .data_o(a_mantissa_p));

    pipe #(.DATA_WIDTH(1),              .LATENCY(REGISTERED_MUX)) b_sign_pipe     (.clk_i(clk_i), .data_i(b_sign_g),     .data_o(b_sign_p));
    pipe #(.DATA_WIDTH(EXPONENT_WIDTH), .LATENCY(REGISTERED_MUX)) b_exponent_pipe (.clk_i(clk_i), .data_i(b_exponent_g), .data_o(b_exponent_p));
    pipe #(.DATA_WIDTH(MANTISSA_WIDTH), .LATENCY(REGISTERED_MUX)) b_mantissa_pipe (.clk_i(clk_i), .data_i(b_mantissa_g), .data_o(b_mantissa_p));

    logic a_gte_b;
    logic a_gte_b_p;

    assign a_gte_b = a_exponent_g >= b_exponent_g;

    pipe #(.DATA_WIDTH(1), .LATENCY(REGISTERED_MUX)) a_gte_pipe (.clk_i(clk_i), .data_i(a_gte_b), .data_o(a_gte_b_p));


    // A swap
    assign a_swap_sign_o     =  a_gte_p ? a_sign_p     : b_sign_p;
    assign a_swap_exponent_o =  a_gte_p ? a_exponent_p : b_exponent_p;
    assign a_swap_mantissa_o =  a_gte_p ? a_mantissa_p : b_mantissa_p;
        
    // B swap
    assign b_swap_sign_o     =  a_gte_p ? b_sign_p     : a_sign_p;
    assign b_swap_exponent_o =  a_gte_p ? b_exponent_p : a_exponent_p;
    assign b_swap_mantissa_o =  a_gte_p ? b_mantissa_p : a_mantissa_p;

endmodule

// Align & Sticky
/*
Align and compute sticky bit.
*/
module abfp_align_sticky#(
    parameter BASE,
    parameter EXPONENT_WIDTH,
    parameter MANTISSA_WIDTH,
    parameter REGISTERED_IN,
    parameter REGISTERED_EXPONENT_MUX,

    ////////////////////////////////////////////////////////////////
    // Globally Defined Locally Set Parameters
    localparam BASE_WIDTH              = alternate_base_fp_BASE_WIDTH(BASE),
    localparam ALIGN_CHOICES           = alternate_base_fp_ALIGN_CHOICES(EXPONENT_WIDTH, MANTISSA_WIDTH),
    localparam EXPONENT_SELECTOR_WIDTH = alternate_base_fp_EXPONENT_SELECTOR_WIDTH(ALIGN_CHOICES),

    localparam int_t [PLANETARY - 1 : 0][1 : 0] STICKY_OR_INDICES = 
        alternate_base_fp_STICKY_OR_INDICES(
            BASE_WIDTH, 
            MANTISSA_WIDTH, 
            ALIGN_CHOICES, 
            LUTX, 
            GRADE
        ),

    localparam STICKY_MAX_LATENCY  = alternate_base_fp_STICKY_MAX_LATENCY (ALIGN_CHOICES, STICKY_OR_INDICES),
    localparam EXPONENT_LATENCY    = alternate_base_fp_EXPONENT_LATENCY   (REGISTERED_EXPONENT_MUX),
    localparam BALANCE_MAX_LATENCY = alternate_base_fp_BALANCE_MAX_LATENCY(STICKY_MAX_LATENCY, EXPONENT_LATENCY)


) (
    input clk_i,

    input                           a_sign_i,
    input  [EXPONENT_WIDTH - 1 : 0] a_exponent_i,
    input  [MANTISSA_WIDTH - 1 : 0] a_mantissa_i,

    input                           b_sign_i,
    input  [EXPONENT_WIDTH - 1 : 0] b_exponent_i,
    input  [MANTISSA_WIDTH - 1 : 0] b_mantissa_i,

    output                                           a_sign_o,
    output [MANTISSA_WIDTH + BASE_WIDTH + 2 - 1 : 0] a_mantissa_grs_o,

    output                                           b_sign_o,
    output [MANTISSA_WIDTH + BASE_WIDTH + 2 - 1 : 0] b_mantissa_grs_o,

    output [EXPONENT_WIDTH - 1 : 0] exponent_o
);

    logic                           a_sign;
    logic  [EXPONENT_WIDTH - 1 : 0] a_exponent;
    logic  [MANTISSA_WIDTH - 1 : 0] a_mantissa;

    logic                           a_sign_g;
    logic  [EXPONENT_WIDTH - 1 : 0] a_exponent_g;
    logic  [MANTISSA_WIDTH - 1 : 0] a_mantissa_g;

    logic                           b_sign;
    logic  [EXPONENT_WIDTH - 1 : 0] b_exponent;
    logic  [MANTISSA_WIDTH - 1 : 0] b_mantissa;

    logic                           b_sign_g;
    logic  [EXPONENT_WIDTH - 1 : 0] b_exponent_g;
    logic  [MANTISSA_WIDTH - 1 : 0] b_mantissa_g;

    always@(posedge clk_i) begin
        a_sign     <= a_sign_i;
        a_exponent <= a_exponent_i;
        a_mantissa <= a_mantissa_i;

        b_sign     <= b_sign_i;
        b_exponent <= b_exponent_i;
        b_mantissa <= b_mantissa_i;
    end

    assign a_sign_g     = (REGISTERED_IN == 1) ? a_sign     : a_sign_i;
    assign a_exponent_g = (REGISTERED_IN == 1) ? a_exponent : a_exponent_i;
    assign a_mantissa_g = (REGISTERED_IN == 1) ? a_mantissa : a_mantissa_i;

    assign b_sign_g     = (REGISTERED_IN == 1) ? b_sign     : b_sign_i;
    assign b_exponent_g = (REGISTERED_IN == 1) ? b_exponent : b_exponent_i;
    assign b_mantissa_g = (REGISTERED_IN == 1) ? b_mantissa : b_mantissa_i;

    ////////////////////////////////////////////////////////////////
    // Exponent Compare
    logic [EXPONENT_WIDTH - 1 : 0]          exponent_difference;
    logic                                   exponent_compare;
    
    always_comb begin
        exponent_difference = a_exponent_g - b_exponent_g; // since a exp >= b exp, no chance of overflow
        exponent_compare  = exponent_difference < ALIGN_CHOICES;
    end

    logic [EXPONENT_WIDTH - 1 : 0]          exponent_difference_p;
    logic                                   exponent_compare_p;
    pipe #(.DATA_WIDTH(EXPONENT_WIDTH), .LATENCY(REGISTERED_EXPONENT_MUX)) exponent_difference_pipe (.clk_i(clk_i), .data_i(exponent_difference), .data_o(exponent_difference_p));
    pipe #(.DATA_WIDTH(EXPONENT_WIDTH), .LATENCY(REGISTERED_EXPONENT_MUX)) exponent_compare_pipe    (.clk_i(clk_i), .data_i(exponent_compare),    .data_o(exponent_compare_p));

    ////////////////////////////////////////////////////////////////
    // Exponent Mux
    logic [EXPONENT_SELECTOR_WIDTH - 1 : 0] exponent_selector;
    assign exponent_selector = exponent_compare_p ? exponent_difference_p[SELECTOR_WIDTH - 1 : 0] : (ALIGN_CHOICES - 1);

      
    ////////////////////////////////////////////////////////////////
    // Sticky Or Tree
    logic [ALIGN_CHOICES - 1 : 0] sticky_choices;
    logic [ALIGN_CHOICES - 1 : 0] sticky_choices_p;
    logic [MANTISSA_WIDTH + BASE_WIDTH + 1 - 1 : 0] sticky_b_mantissa_gr;
    assign sticky_b_mantissa_gr = {b_mantissa_g, {BASE_WIDTH{1'b0}}, 1'b0};

    generate
        for(genvar c = 0; c < ALIGN_CHOICES; c++) begin
            if(STICKY_OR_INDICES[c][0] == -1) begin
                assign sticky_choices[c] = 0;
            end else begin
                reduction_tree #(
                    .DATA_WIDTH(STICKY_OR_INDICES[c][0] - (BASE_WIDTH + 1) + 1),
                    .GATE(1),
                    .REGISTERED_IN(0),
                    .LUTX(LUTX),
                    .GRADE(GRADE)
                ) sticky_or_tree_inst (
                    .clk_i(clk_i),
                    .data_i   (sticky_b_mantissa_gr[STICKY_OR_INDICES[c][0] : (BASE_WIDTH + 1)]),
                    .reduced_o(sticky_choices_p[c])
                );

                pipe #(.DATA_WIDTH(1), .LATENCY(STICKY_MAX_LATENCY - STICKY_OR_INDICES[c][1])
                ) sticky_or_pipe_inst (
                    .clk_i(clk_i),
                    .data_i(sticky_choices_p[c]),
                    .data_o(sticky_choices[c])
                );

            end
        end
    endgenerate


    ////////////////////////////////////////////////////////////////
    // Mantissa Align Mux
    logic [ALIGN_CHOICES - 1 : 0][MANTISSA_WIDTH + BASE_WIDTH + 1 - 1 : 0] align_mantissa_gr;
    always_comb begin
        for(int c = ALIGN_CHOICES; c < ALIGN_CHOICES; c++) begin
            
        end
    end


    ////////////////////////////////////////////////////////////////
    // Sticky Align Mux




    /*
    [xxxx][xxxx][xxxx][gggg][rs] - 0
    [0000][xxxx][xxxx][gggg][rs] - 1
    [0000][0000][xxxx][gggg][rs] - 2
    [0000][0000][0000][gggg][rs] - 3
    ----------------------------
    [0000][0000][0000][0000][rs] - underflow


    // out is when exponent < -1 (-2 and beyond), count
    [xxxx][xxxx][xxxx][xxxg][grs]
    [0000][0000][0000][0000]

    complete groups tells us so


    */




    assign exponent_o = a_exponent_g;



endmodule

// Adder
/*
Add according to signs. I think we can stick conversion back
here.
*/

module abfp_adder #(

) (

);

endmodule

module abfp_normalizer #(

) (

);

endmodule

module abfp_rounder #(

) (

);

endmodule
