/* 
A 4-stage pipelined alternate base floating point adder with customizable exponent
and mantissa widths, inspired by the IBM hexadecimal floating point and necesitated
by the need to make compute cheap. Tradeoff is loss in precision due to wobbling
precision and inability to use implicit leading bit. Base selected must be a power
of 2.

Keep MANTISSA_WIDTH / log2(BASE) < 4, to ensure that our largest muxes are 4:1, which fit 
perfectly into LUT6. 

Subnormal numbers are not supported, meaning exponent underflow simply results in 0. 
Zero results have exponent zero and mantissa zero; their sign is preserved.

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
- Must be at least log2(BASE), so one radix digit fits in the mantissa.

REGISTERED_* [0, 1]:
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


    ////////////////////////////////////////////////////////////////
    // Globally Defined Locally Set Parameters
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
) (
    input clk_i,
    input  [DATA_WIDTH - 1 : 0] a_i,
    input  [DATA_WIDTH - 1 : 0] b_i,
    output [DATA_WIDTH - 1 : 0] sum_o
);
    ////////////////////////////////////////////////////////////////
    // Swap
    logic a_swap_sign;
    logic [EXPONENT_WIDTH - 1 : 0] a_swap_exponent;
    logic [MANTISSA_WIDTH - 1 : 0] a_swap_mantissa;
    logic b_swap_sign;
    logic [EXPONENT_WIDTH - 1 : 0] b_swap_exponent;
    logic [MANTISSA_WIDTH - 1 : 0] b_swap_mantissa;

    abfp_swap #(
        .BASE(BASE),
        .EXPONENT_WIDTH(EXPONENT_WIDTH),
        .MANTISSA_WIDTH(MANTISSA_WIDTH),
        .REGISTERED_IN(REGISTERED_SWAP_IN),
        .REGISTERED_MUX(REGISTERED_SWAP_MUX)
    ) swap_inst (
        .clk_i(clk_i),
        .a_sign_i(a_i[DATA_WIDTH - 1]),
        .a_exponent_i(a_i[MANTISSA_WIDTH + EXPONENT_WIDTH - 1 : MANTISSA_WIDTH]),
        .a_mantissa_i(a_i[MANTISSA_WIDTH - 1 : 0]),
        .b_sign_i(b_i[DATA_WIDTH - 1]),
        .b_exponent_i(b_i[MANTISSA_WIDTH + EXPONENT_WIDTH - 1 : MANTISSA_WIDTH]),
        .b_mantissa_i(b_i[MANTISSA_WIDTH - 1 : 0]),
        .a_swap_sign_o(a_swap_sign),
        .a_swap_exponent_o(a_swap_exponent),
        .a_swap_mantissa_o(a_swap_mantissa),
        .b_swap_sign_o(b_swap_sign),
        .b_swap_exponent_o(b_swap_exponent),
        .b_swap_mantissa_o(b_swap_mantissa)
    );

    ////////////////////////////////////////////////////////////////
    // Align & Sticky
    logic a_align_sign;
    logic [MANTISSA_WIDTH + BASE_WIDTH + 2 - 1 : 0] a_align_mantissa_grs;
    logic b_align_sign;
    logic [MANTISSA_WIDTH + BASE_WIDTH + 2 - 1 : 0] b_align_mantissa_grs;
    logic [EXPONENT_WIDTH - 1 : 0] align_exponent;

    abfp_align_sticky #(
        .BASE(BASE),
        .EXPONENT_WIDTH(EXPONENT_WIDTH),
        .MANTISSA_WIDTH(MANTISSA_WIDTH),
        .REGISTERED_IN(REGISTERED_ALIGN_STICKY_IN),
        .REGISTERED_EXPONENT_MUX(REGISTERED_ALIGN_EXPONENT_MUX),
        .REGISTERED_ALIGN_MUX(REGISTERED_ALIGN_MUX),
        .LUTX(LUTX),
        .GRADE(GRADE)
    ) align_sticky_inst (
        .clk_i(clk_i),
        .a_sign_i(a_swap_sign),
        .a_exponent_i(a_swap_exponent),
        .a_mantissa_i(a_swap_mantissa),
        .b_sign_i(b_swap_sign),
        .b_exponent_i(b_swap_exponent),
        .b_mantissa_i(b_swap_mantissa),
        .a_sign_o(a_align_sign),
        .a_mantissa_grs_o(a_align_mantissa_grs),
        .b_sign_o(b_align_sign),
        .b_mantissa_grs_o(b_align_mantissa_grs),
        .exponent_o(align_exponent)
    );

    ////////////////////////////////////////////////////////////////
    // Add & Convert
    logic add_convert_sign;
    logic [1 + MANTISSA_WIDTH + BASE_WIDTH + 2 - 1 : 0] add_convert_mantissa_grs;
    logic [EXPONENT_WIDTH - 1 : 0] add_convert_exponent;

    abfp_add_convert #(
        .BASE(BASE),
        .EXPONENT_WIDTH(EXPONENT_WIDTH),
        .MANTISSA_WIDTH(MANTISSA_WIDTH),
        .REGISTERED_IN(REGISTERED_ADD_CONVERT),
        .REGISTERED_CONVERT(REGISTERED_ADD_CONVERT_CONVERT)
    ) add_convert_inst (
        .clk_i(clk_i),
        .a_sign_i(a_align_sign),
        .a_mantissa_grs_i(a_align_mantissa_grs),
        .b_sign_i(b_align_sign),
        .b_mantissa_grs_i(b_align_mantissa_grs),
        .exponent_i(align_exponent),
        .r_sign_o(add_convert_sign),
        .r_mantissa_grs_o(add_convert_mantissa_grs),
        .r_exponent_o(add_convert_exponent)
    );

    ////////////////////////////////////////////////////////////////
    // Priority Encode
    logic priority_encode_sign;
    logic [1 + MANTISSA_WIDTH + BASE_WIDTH + 2 - 1 : 0] priority_encode_mantissa_grs;
    logic [EXPONENT_WIDTH - 1 : 0] priority_encode_exponent;
    logic [PRIORITY_ENCODER_SELECTOR_WIDTH - 1 : 0] priority_encoded;

    abfp_priority_encode #(
        .BASE(BASE),
        .EXPONENT_WIDTH(EXPONENT_WIDTH),
        .MANTISSA_WIDTH(MANTISSA_WIDTH),
        .REGISTERED_IN(REGISTERED_PRIORITY_ENCODE),
        .REGISTERED_PRIORITY_ENCODER(REGISTERED_PRIORITY_ENCODE_ENCODER),
        .LUTX(LUTX),
        .GRADE(GRADE)
    ) priority_encode_inst (
        .clk_i(clk_i),
        .r_sign_i(add_convert_sign),
        .r_mantissa_grs_i(add_convert_mantissa_grs),
        .r_exponent_i(add_convert_exponent),
        .r_sign_o(priority_encode_sign),
        .r_mantissa_grs_o(priority_encode_mantissa_grs),
        .r_exponent_o(priority_encode_exponent),
        .priority_encoded_o(priority_encoded)
    );

    ////////////////////////////////////////////////////////////////
    // Normalize, Round & Post Normalize
    abfp_normalize_round_post_normalize #(
        .BASE(BASE),
        .EXPONENT_WIDTH(EXPONENT_WIDTH),
        .MANTISSA_WIDTH(MANTISSA_WIDTH),
        .REGISTERED_IN(REGISTERED_NORMALIZE_ROUND_POST_NORMALIZE),
        .REGISTERED_ROUND(REGISTERED_NORMALIZE_ROUND_POST_NORMALIZE_ROUND),
        .LUTX(LUTX),
        .GRADE(GRADE)
    ) normalize_round_post_normalize_inst (
        .clk_i(clk_i),
        .r_sign_i(priority_encode_sign),
        .r_mantissa_grs_i(priority_encode_mantissa_grs),
        .r_exponent_i(priority_encode_exponent),
        .priority_encoded_i(priority_encoded),
        .sum_o(sum_o)
    );

endmodule

// Swap
/*
Swap 'a' with 'b' if 'b' has a higher exponent.
*/
module abfp_swap #(
    parameter BASE,
    parameter EXPONENT_WIDTH,
    parameter MANTISSA_WIDTH,
    parameter REGISTERED_IN,
    parameter REGISTERED_MUX,

    ////////////////////////////////////////////////////////////////
    // Globally Defined Locally Set Parameters 
    localparam LATENCY = alternate_base_fp_adder_SWAP_LATENCY(REGISTERED_IN, REGISTERED_MUX)
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
    output [MANTISSA_WIDTH - 1 : 0] b_swap_mantissa_o
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
    assign a_swap_sign_o     =  a_gte_b_p ? a_sign_p     : b_sign_p;
    assign a_swap_exponent_o =  a_gte_b_p ? a_exponent_p : b_exponent_p;
    assign a_swap_mantissa_o =  a_gte_b_p ? a_mantissa_p : b_mantissa_p;
        
    // B swap
    assign b_swap_sign_o     =  a_gte_b_p ? b_sign_p     : a_sign_p;
    assign b_swap_exponent_o =  a_gte_b_p ? b_exponent_p : a_exponent_p;
    assign b_swap_mantissa_o =  a_gte_b_p ? b_mantissa_p : a_mantissa_p;

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
    parameter REGISTERED_ALIGN_MUX,
    parameter LUTX,
    parameter GRADE,

    ////////////////////////////////////////////////////////////////
    // Globally Defined Locally Set Parameters
    localparam BASE_WIDTH              = alternate_base_fp_adder_BASE_WIDTH(BASE),
    localparam ALIGN_CHOICES           = alternate_base_fp_adder_ALIGN_CHOICES(BASE_WIDTH, MANTISSA_WIDTH),
    localparam EXPONENT_SELECTOR_WIDTH = alternate_base_fp_adder_EXPONENT_SELECTOR_WIDTH(ALIGN_CHOICES),

    localparam int_t [PLANETARY - 1 : 0][1 : 0] STICKY_OR_INDICES = 
        alternate_base_fp_adder_STICKY_OR_INDICES(
            BASE_WIDTH, 
            MANTISSA_WIDTH, 
            ALIGN_CHOICES, 
            LUTX, 
            GRADE
        ),

    localparam STICKY_MAX_LATENCY  = alternate_base_fp_adder_STICKY_MAX_LATENCY (ALIGN_CHOICES, STICKY_OR_INDICES),
    localparam EXPONENT_LATENCY    = alternate_base_fp_adder_EXPONENT_LATENCY   (REGISTERED_EXPONENT_MUX),
    localparam BALANCE_MAX_LATENCY = alternate_base_fp_adder_BALANCED_MAX_LATENCY(STICKY_MAX_LATENCY, EXPONENT_LATENCY),

    // align mux related
    localparam ALIGN_MUX_GROUP_SELECTOR_WIDTH = multistage_mux_GROUP_SELECTOR_WIDTH(LUTX, GRADE),
    localparam ALIGN_MUX_GROUP_SIZE           = multistage_mux_GROUP_SIZE(ALIGN_MUX_GROUP_SELECTOR_WIDTH),
    localparam ALIGN_MUX_STAGES               = multistage_mux_STAGES(ALIGN_MUX_GROUP_SIZE, ALIGN_CHOICES),
    localparam ALIGN_MUX_LATENCY              = multistage_mux_LATENCY(REGISTERED_ALIGN_MUX, ALIGN_MUX_STAGES),

    localparam LATENCY = alternate_base_fp_adder_align_sticky_LATENCY(
        BASE, MANTISSA_WIDTH, REGISTERED_IN, REGISTERED_EXPONENT_MUX, REGISTERED_ALIGN_MUX, LUTX, GRADE
    )

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
    pipe #(.DATA_WIDTH(1), .LATENCY(REGISTERED_EXPONENT_MUX)) exponent_compare_pipe    (.clk_i(clk_i), .data_i(exponent_compare),    .data_o(exponent_compare_p));

    ////////////////////////////////////////////////////////////////
    // Exponent Mux
    logic [EXPONENT_SELECTOR_WIDTH - 1 : 0] exponent_selector;
    assign exponent_selector = exponent_compare_p ? EXPONENT_SELECTOR_WIDTH'(exponent_difference_p) : EXPONENT_SELECTOR_WIDTH'(ALIGN_CHOICES - 1);

    logic [EXPONENT_SELECTOR_WIDTH - 1 : 0] exponent_selector_p;
    pipe #(.DATA_WIDTH(EXPONENT_SELECTOR_WIDTH), .LATENCY(BALANCE_MAX_LATENCY - EXPONENT_LATENCY)) a_exp_sel_pipe (.clk_i(clk_i), .data_i(exponent_selector), .data_o(exponent_selector_p));

      
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
                assign sticky_choices_p[c] = 0;
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
                    .reduced_o(sticky_choices[c])
                );

                pipe #(.DATA_WIDTH(1), .LATENCY(BALANCE_MAX_LATENCY - STICKY_OR_INDICES[c][1])
                ) sticky_or_pipe_inst (
                    .clk_i(clk_i),
                    .data_i(sticky_choices[c]),
                    .data_o(sticky_choices_p[c])
                );
            end
        end
    endgenerate


    ////////////////////////////////////////////////////////////////
    // A, B Pipelines 
    logic                           a_sign_p;
    logic  [EXPONENT_WIDTH - 1 : 0] a_exponent_p;
    logic  [MANTISSA_WIDTH - 1 : 0] a_mantissa_p;

    logic                           b_sign_p;
    logic  [EXPONENT_WIDTH - 1 : 0] b_exponent_p;
    logic  [MANTISSA_WIDTH - 1 : 0] b_mantissa_p;

    pipe #(.DATA_WIDTH(1),              .LATENCY(BALANCE_MAX_LATENCY + ALIGN_MUX_LATENCY)) a_sign_pipe     (.clk_i(clk_i), .data_i(a_sign_g)    , .data_o(a_sign_p));
    pipe #(.DATA_WIDTH(EXPONENT_WIDTH), .LATENCY(BALANCE_MAX_LATENCY + ALIGN_MUX_LATENCY)) a_exponent_pipe (.clk_i(clk_i), .data_i(a_exponent_g), .data_o(a_exponent_p));
    pipe #(.DATA_WIDTH(MANTISSA_WIDTH), .LATENCY(BALANCE_MAX_LATENCY + ALIGN_MUX_LATENCY)) a_mantissa_pipe (.clk_i(clk_i), .data_i(a_mantissa_g), .data_o(a_mantissa_p));

    pipe #(.DATA_WIDTH(1),              .LATENCY(BALANCE_MAX_LATENCY + ALIGN_MUX_LATENCY)) b_sign_pipe     (.clk_i(clk_i), .data_i(b_sign_g)    ,.data_o(b_sign_p));
    pipe #(.DATA_WIDTH(MANTISSA_WIDTH), .LATENCY(BALANCE_MAX_LATENCY)) b_mantissa_pipe (.clk_i(clk_i), .data_i(b_mantissa_g),.data_o(b_mantissa_p));

    ////////////////////////////////////////////////////////////////
    // Mantissa Align Mux
    logic [ALIGN_CHOICES - 1 : 0][MANTISSA_WIDTH + BASE_WIDTH + 1 - 1 : 0] align_mantissa_gr_choices;
    always_comb begin
        for(int c = 0; c < ALIGN_CHOICES; c++) begin
            align_mantissa_gr_choices[c] = {b_mantissa_p, {BASE_WIDTH{1'b0}}, 1'b0};
            align_mantissa_gr_choices[c] = align_mantissa_gr_choices[c] >> (c * BASE_WIDTH);
        end
    end

    logic [MANTISSA_WIDTH + BASE_WIDTH + 1 - 1 : 0] aligned_mantissa_gr;
    multistage_mux #(
        .DATA_WIDTH(MANTISSA_WIDTH + BASE_WIDTH + 1),
        .SIZE(ALIGN_CHOICES),
        .REGISTERED_IN(REGISTERED_ALIGN_MUX),
        .LUTX(LUTX),
        .GRADE(GRADE)
    ) align_mantissa_mux (
        .clk_i(clk_i),
        .data_i(align_mantissa_gr_choices),
        .sel_i (exponent_selector_p),
        .data_o(aligned_mantissa_gr)
    );


    ////////////////////////////////////////////////////////////////
    // Sticky Align Mux
    logic aligned_sticky;
    multistage_mux #(
        .DATA_WIDTH(1),
        .SIZE(ALIGN_CHOICES),
        .REGISTERED_IN(REGISTERED_ALIGN_MUX),
        .LUTX(LUTX),
        .GRADE(GRADE)
    ) align_sticky_mux (
        .clk_i(clk_i),
        .data_i(sticky_choices_p),
        .sel_i (exponent_selector_p),
        .data_o(aligned_sticky)
    );

    assign a_sign_o         = a_sign_p;
    assign a_mantissa_grs_o = {a_mantissa_p,{BASE_WIDTH{1'b0}}, 1'b0, 1'b0};

    assign b_sign_o         = b_sign_p;
    assign b_mantissa_grs_o = {aligned_mantissa_gr, aligned_sticky};

    assign exponent_o       = a_exponent_p;
endmodule

// Add & Convert
/*
Add according to signs. I think we can stick conversion back
here.
*/

module abfp_add_convert #(
    parameter BASE,
    parameter EXPONENT_WIDTH,
    parameter MANTISSA_WIDTH,
    parameter REGISTERED_IN,
    parameter REGISTERED_CONVERT,

    ////////////////////////////////////////////////////////////////
    // Globally Defined Locally Set Parameters
    localparam BASE_WIDTH = alternate_base_fp_adder_BASE_WIDTH(BASE),
    localparam LATENCY    = alternate_base_fp_adder_add_convert_LATENCY(REGISTERED_IN, REGISTERED_CONVERT)

) (
    input clk_i,

    input                                           a_sign_i,
    input [MANTISSA_WIDTH + BASE_WIDTH + 2 - 1 : 0] a_mantissa_grs_i,

    input                                           b_sign_i,
    input [MANTISSA_WIDTH + BASE_WIDTH + 2 - 1 : 0] b_mantissa_grs_i,

    input [EXPONENT_WIDTH - 1 : 0] exponent_i,

    output                                                 r_sign_o,
    output [1 + MANTISSA_WIDTH + BASE_WIDTH + 2 - 1  :  0] r_mantissa_grs_o,
    output [EXPONENT_WIDTH - 1 : 0]                        r_exponent_o

);
    logic                                           a_sign;
    logic [MANTISSA_WIDTH + BASE_WIDTH + 2 - 1 : 0] a_mantissa_grs;
    logic                                           b_sign;
    logic [MANTISSA_WIDTH + BASE_WIDTH + 2 - 1 : 0] b_mantissa_grs;
    logic [EXPONENT_WIDTH - 1 : 0] exponent;

    logic                                           a_sign_g;
    logic [MANTISSA_WIDTH + BASE_WIDTH + 2 - 1 : 0] a_mantissa_grs_g;
    logic                                           b_sign_g;
    logic [MANTISSA_WIDTH + BASE_WIDTH + 2 - 1 : 0] b_mantissa_grs_g;

    logic [EXPONENT_WIDTH - 1 : 0] exponent_g;

    always@(posedge clk_i) begin
        a_sign         <= a_sign_i;
        a_mantissa_grs <= a_mantissa_grs_i;
        b_sign         <= b_sign_i;
        b_mantissa_grs <= b_mantissa_grs_i;
        exponent       <= exponent_i;
    end

    assign a_sign_g         = (REGISTERED_IN == 1) ? a_sign         : a_sign_i;
    assign a_mantissa_grs_g = (REGISTERED_IN == 1) ? a_mantissa_grs : a_mantissa_grs_i;
    assign b_sign_g         = (REGISTERED_IN == 1) ? b_sign         : b_sign_i;
    assign b_mantissa_grs_g = (REGISTERED_IN == 1) ? b_mantissa_grs : b_mantissa_grs_i;
    assign exponent_g       = (REGISTERED_IN == 1) ? exponent       : exponent_i;

    logic [EXPONENT_WIDTH - 1 : 0] r_exponent_p;
    pipe #(.DATA_WIDTH(EXPONENT_WIDTH), .LATENCY(REGISTERED_CONVERT)) r_exponent_pipe (.clk_i(clk_i), .data_i(exponent_g), .data_o(r_exponent_p));

    ////////////////////////////////////////////////////////////////
    // Adder stage

    logic [1 + MANTISSA_WIDTH + BASE_WIDTH + 2 - 1  :  0] a_mantissa_grs_g_pad;
    logic [1 + MANTISSA_WIDTH + BASE_WIDTH + 2 - 1  :  0] b_mantissa_grs_g_pad;

    assign a_mantissa_grs_g_pad = {1'b0, a_mantissa_grs_g};
    assign b_mantissa_grs_g_pad = {1'b0, b_mantissa_grs_g};

    logic [1 + MANTISSA_WIDTH + BASE_WIDTH + 2 - 1  :  0] r_mantissa_grs;
    logic [1 + MANTISSA_WIDTH + BASE_WIDTH + 2 - 1  :  0] r_mantissa_grs_p; 

    /* 
    Used to determine how the MSB should be interpreted as sign or
    overflow bit. If false, then as carry, if true, then as sign;
    Then, if it is a sign and negative, it means we need to convert
    back to unsigned in the next stage.
    */
    logic r_different_sign; 
    logic r_different_sign_p;

    logic r_sign;
    logic r_sign_p;
    
    // note example bug if *_pad not used.
    always_comb begin
        if(a_sign_g == b_sign_g) begin
            r_mantissa_grs = a_mantissa_grs_g_pad + b_mantissa_grs_g_pad;
        end else if((!a_sign_g) & b_sign_g) begin
            r_mantissa_grs = a_mantissa_grs_g_pad - b_mantissa_grs_g_pad;
        end else begin
            r_mantissa_grs = b_mantissa_grs_g_pad - a_mantissa_grs_g_pad;
        end

        r_different_sign = a_sign_g ^ b_sign_g;
        r_sign           = r_different_sign ? r_mantissa_grs[1 + MANTISSA_WIDTH + BASE_WIDTH + 2 - 1] : a_sign_g;
    end

    pipe #(.DATA_WIDTH(MANTISSA_WIDTH + BASE_WIDTH + 2 + 1), .LATENCY(REGISTERED_CONVERT)) r_mantissa_grs_pipe   (.clk_i(clk_i), .data_i(r_mantissa_grs)  ,.data_o(r_mantissa_grs_p));
    pipe #(.DATA_WIDTH(1), .LATENCY(REGISTERED_CONVERT))                                   r_different_sign_pipe (.clk_i(clk_i), .data_i(r_different_sign),.data_o(r_different_sign_p));
    pipe #(.DATA_WIDTH(1), .LATENCY(REGISTERED_CONVERT))                                   r_sign_pipe           (.clk_i(clk_i), .data_i(r_sign),          .data_o(r_sign_p));

    ////////////////////////////////////////////////////////////////
    // Convert stage
    logic [1 + MANTISSA_WIDTH + BASE_WIDTH + 2 - 1  :  0] r_mantissa_grs_converted;
    always_comb begin
        if(r_different_sign_p) begin // interpret MSB as sign, convert if necessary
            if(r_sign_p) begin 
                r_mantissa_grs_converted = (~r_mantissa_grs_p) + 1;
                /* Overflow is not an issue, as the bits are reinterpreted as unsigned.
                I.e 4-bit signed, 1000 = -8, 1000 -> 0111 + 1 -> 1000 is 8, not -8
                */
            end else begin
                r_mantissa_grs_converted = r_mantissa_grs_p;
            end
        end else begin               // interpret MSB as overflow, do nothing.
            r_mantissa_grs_converted = r_mantissa_grs_p;
        end
    end  

    assign r_sign_o         = r_sign_p;
    assign r_mantissa_grs_o = r_mantissa_grs_converted;
    assign r_exponent_o     = r_exponent_p;

endmodule

// Priority Encode
/*
Leading one detection using the or reduced values to get selector
value for normalize stage and exponent inc/dec to be added.
*/

module abfp_priority_encode #(
    parameter BASE,
    parameter EXPONENT_WIDTH,
    parameter MANTISSA_WIDTH,
    parameter REGISTERED_IN,
    parameter REGISTERED_PRIORITY_ENCODER,
    parameter LUTX,
    parameter GRADE,

    ////////////////////////////////////////////////////////////////
    // Globally Defined Locally Set Parameters
    localparam BASE_WIDTH               = alternate_base_fp_adder_BASE_WIDTH(BASE),
    localparam NORMALIZE_CHOICES        = alternate_base_fp_adder_NORMALIZE_CHOICES(BASE_WIDTH, MANTISSA_WIDTH),
    localparam NORMALIZE_OR_MAX_LATENCY = alternate_base_fp_adder_NORMALIZE_OR_MAX_LATENCY(LUTX, GRADE, MANTISSA_WIDTH, BASE_WIDTH, NORMALIZE_CHOICES),
    localparam int_t [PLANETARY - 1 : 0][2 : 0] NORMALIZE_OR_INDICES = 
        alternate_base_fp_adder_NORMALIZE_OR_INDICES(
            BASE_WIDTH, 
            MANTISSA_WIDTH, 
            NORMALIZE_CHOICES, 
            LUTX, 
            GRADE
        ),
    localparam PRIORITY_ENCODER_SELECTOR_WIDTH = priority_encoder_OUTPUT_DATA_WIDTH(NORMALIZE_CHOICES),

    localparam PRIORITY_ENCODER_ENCODE_GROUPS              = priority_encoder_ENCODE_GROUPS(NORMALIZE_CHOICES, LUTX),
    localparam PRIORITY_ENCODER_ENCODE_DEPTH               = priority_encoder_ENCODE_DEPTH(PRIORITY_ENCODER_ENCODE_GROUPS),
    localparam PRIORITY_ENCODER_ENCODE_FIRST_LAYER_LATENCY = max_LATENCY(1, GRADE),
    localparam PRIORITY_ENCODER_ENCODE_REST_LAYERS_LATENCY = max_LATENCY(0, GRADE),
    localparam PRIORITY_ENCODER_LATENCY = priority_encoder_LATENCY(
        REGISTERED_PRIORITY_ENCODER, 
        PRIORITY_ENCODER_ENCODE_DEPTH, 
        PRIORITY_ENCODER_ENCODE_FIRST_LAYER_LATENCY, 
        PRIORITY_ENCODER_ENCODE_REST_LAYERS_LATENCY),

    localparam LATENCY = alternate_base_fp_adder_priority_encoder_LATENCY(
        BASE, MANTISSA_WIDTH, REGISTERED_IN, REGISTERED_PRIORITY_ENCODER, LUTX, GRADE
    )

) (
    input clk_i,

    input                                                 r_sign_i,
    input [1 + MANTISSA_WIDTH + BASE_WIDTH + 2 - 1  :  0] r_mantissa_grs_i,
    input [EXPONENT_WIDTH - 1 : 0]                        r_exponent_i,

    output                                                 r_sign_o,
    output [1 + MANTISSA_WIDTH + BASE_WIDTH + 2 - 1  :  0] r_mantissa_grs_o,
    output [EXPONENT_WIDTH - 1 : 0]                        r_exponent_o,
    output [PRIORITY_ENCODER_SELECTOR_WIDTH - 1 : 0]       priority_encoded_o
); 

    logic                                                 r_sign;
    logic [1 + MANTISSA_WIDTH + BASE_WIDTH + 2 - 1  :  0] r_mantissa_grs;
    logic [EXPONENT_WIDTH - 1 : 0]                        r_exponent;

    logic                                                 r_sign_g;
    logic [1 + MANTISSA_WIDTH + BASE_WIDTH + 2 - 1  :  0] r_mantissa_grs_g;
    logic [EXPONENT_WIDTH - 1 : 0]                        r_exponent_g;

    always@(posedge clk_i) begin
        r_sign         <= r_sign_i;
        r_mantissa_grs <= r_mantissa_grs_i;
        r_exponent     <= r_exponent_i;
    end

    assign r_sign_g         = (REGISTERED_IN == 1) ? r_sign         : r_sign_i;
    assign r_mantissa_grs_g = (REGISTERED_IN == 1) ? r_mantissa_grs : r_mantissa_grs_i;
    assign r_exponent_g     = (REGISTERED_IN == 1) ? r_exponent     : r_exponent_i;

    ////////////////////////////////////////////////////////////////
    // Or Reductions
    logic [NORMALIZE_CHOICES - 1 : 0] normalize_or_reductions;
    logic [NORMALIZE_CHOICES - 1 : 0] normalize_or_reductions_p;

    generate
        for(genvar c = 0; c < NORMALIZE_CHOICES; c++) begin
            reduction_tree #(
                .DATA_WIDTH(NORMALIZE_OR_INDICES[c][0] - NORMALIZE_OR_INDICES[c][1] + 1),
                .GATE(1),
                .REGISTERED_IN(0),
                .LUTX(LUTX),
                .GRADE(GRADE)
            ) norm_or_reduce_inst (
                .clk_i(clk_i),
                .data_i   (r_mantissa_grs_g[NORMALIZE_OR_INDICES[c][0] : NORMALIZE_OR_INDICES[c][1]]),
                .reduced_o(normalize_or_reductions[c])
            );

            pipe #(
                .DATA_WIDTH(1),
                .LATENCY(NORMALIZE_OR_MAX_LATENCY - NORMALIZE_OR_INDICES[c][2])
            ) norm_or_reduce_pipe (
                .clk_i(clk_i),
                .data_i(normalize_or_reductions[c]),
                .data_o(normalize_or_reductions_p[c])
            );
        end
    endgenerate

    ////////////////////////////////////////////////////////////////
    // Priority Encoder
    logic [PRIORITY_ENCODER_SELECTOR_WIDTH - 1 : 0] selector;
    priority_encoder #(
        .INPUT_DATA_WIDTH(NORMALIZE_CHOICES),
        .REGISTERED_IN(REGISTERED_PRIORITY_ENCODER),
        .LUTX(LUTX),
        .GRADE(GRADE)
    ) lead_one_priority_encoder (
        .clk_i(clk_i),
        .priority_i(normalize_or_reductions_p),
        .priority_encoded_o(selector)
    );

    ////////////////////////////////////////////////////////////////
    // Pipes
    logic                                                 r_sign_p;
    logic [1 + MANTISSA_WIDTH + BASE_WIDTH + 2 - 1  :  0] r_mantissa_grs_p;
    logic [EXPONENT_WIDTH - 1 : 0]                        r_exponent_p;

    pipe #(
        .DATA_WIDTH(1),
        .LATENCY(PRIORITY_ENCODER_LATENCY + NORMALIZE_OR_MAX_LATENCY)
    ) r_sign_pipe (
        .clk_i(clk_i),
        .data_i(r_sign_g),
        .data_o(r_sign_p)
    );

    pipe #(
        .DATA_WIDTH(1 + MANTISSA_WIDTH + BASE_WIDTH + 2),
        .LATENCY(PRIORITY_ENCODER_LATENCY + NORMALIZE_OR_MAX_LATENCY)
    ) r_mantissa_grs_pipe (
        .clk_i(clk_i),
        .data_i(r_mantissa_grs_g),
        .data_o(r_mantissa_grs_p)
    );

    pipe #(
        .DATA_WIDTH(EXPONENT_WIDTH),
        .LATENCY(PRIORITY_ENCODER_LATENCY + NORMALIZE_OR_MAX_LATENCY)
    ) r_exponent_pipe (
        .clk_i(clk_i),
        .data_i(r_exponent_g),
        .data_o(r_exponent_p)
    );

    assign r_sign_o           = r_sign_p;
    assign r_mantissa_grs_o   = r_mantissa_grs_p;
    assign r_exponent_o       = r_exponent_p;
    assign priority_encoded_o = selector;

endmodule

// Noramlize, Round, Post Normalize
/*
Normalize, round then post normalize. Note that for the post normalize
step, we don't need a 2:1 mux, instead we can take advantage of the fact
that all the mantissa bits besides the carry will become 0 and do a bit
OR mask on just where it would be shifted to (in addition to incrementing
the exponent).
*/

module abfp_normalize_round_post_normalize #(
    parameter BASE,
    parameter EXPONENT_WIDTH,
    parameter MANTISSA_WIDTH,
    parameter REGISTERED_IN,
    parameter REGISTERED_ROUND,
    parameter LUTX,
    parameter GRADE,

    ////////////////////////////////////////////////////////////////
    // Globally Defined Locally Set Parameters
    localparam DATA_WIDTH = alternate_base_fp_adder_DATA_WIDTH(EXPONENT_WIDTH, MANTISSA_WIDTH),
    localparam BASE_WIDTH                      = alternate_base_fp_adder_BASE_WIDTH(BASE),
    localparam NORMALIZE_CHOICES               = alternate_base_fp_adder_NORMALIZE_CHOICES(BASE_WIDTH, MANTISSA_WIDTH),
    localparam PRIORITY_ENCODER_SELECTOR_WIDTH = priority_encoder_OUTPUT_DATA_WIDTH(NORMALIZE_CHOICES),
    localparam EXPONENT_MAX_WIDTH              = alternate_base_fp_adder_EXPONENT_MAX_WIDTH(EXPONENT_WIDTH, NORMALIZE_CHOICES),
    localparam logic [EXPONENT_MAX_WIDTH - 1 : 0] EXPONENT_MAX_VALUE = EXPONENT_MAX_WIDTH'({EXPONENT_WIDTH{1'b1}}),
    localparam POST_NORMALIZE_CARRY_INDEX = max(0, MANTISSA_WIDTH - BASE_WIDTH),

    localparam MULTISTAGE_MUX_GROUP_SELECTOR_WIDTH = multistage_mux_GROUP_SELECTOR_WIDTH(LUTX, GRADE),
    localparam MULTISTAGE_MUX_GROUP_SIZE           = multistage_mux_GROUP_SIZE(MULTISTAGE_MUX_GROUP_SELECTOR_WIDTH),
    localparam MULTISTAGE_MUX_STAGES               = multistage_mux_STAGES(MULTISTAGE_MUX_GROUP_SIZE, NORMALIZE_CHOICES),
    localparam MULTISTAGE_MUX_LATENCY              = multistage_mux_LATENCY(0, MULTISTAGE_MUX_STAGES),

    localparam LATENCY = alternate_base_fp_adder_normalize_round_post_normalize_LATENCY(
        BASE, MANTISSA_WIDTH, REGISTERED_IN, REGISTERED_ROUND, LUTX, GRADE
    )
) (
    input clk_i,

    input                                                 r_sign_i,
    input [1 + MANTISSA_WIDTH + BASE_WIDTH + 2 - 1  :  0] r_mantissa_grs_i,
    input [EXPONENT_WIDTH - 1 : 0]                        r_exponent_i,
    input [PRIORITY_ENCODER_SELECTOR_WIDTH - 1 : 0]       priority_encoded_i,

    output [DATA_WIDTH - 1 : 0] sum_o
);

    logic                                                 r_sign;
    logic [1 + MANTISSA_WIDTH + BASE_WIDTH + 2 - 1  :  0] r_mantissa_grs;
    logic [EXPONENT_WIDTH - 1 : 0]                        r_exponent;
    logic [PRIORITY_ENCODER_SELECTOR_WIDTH - 1 : 0]       priority_encoded;

    logic                                                 r_sign_g;
    logic [1 + MANTISSA_WIDTH + BASE_WIDTH + 2 - 1  :  0] r_mantissa_grs_g;
    logic [EXPONENT_WIDTH - 1 : 0]                        r_exponent_g;
    logic [PRIORITY_ENCODER_SELECTOR_WIDTH - 1 : 0]       priority_encoded_g;

    always@(posedge clk_i) begin
        r_sign           <= r_sign_i;
        r_mantissa_grs   <= r_mantissa_grs_i;
        r_exponent       <= r_exponent_i;
        priority_encoded <= priority_encoded_i;
    end

    assign r_sign_g           = (REGISTERED_IN == 1) ? r_sign           : r_sign_i;
    assign r_mantissa_grs_g   = (REGISTERED_IN == 1) ? r_mantissa_grs   : r_mantissa_grs_i;
    assign r_exponent_g       = (REGISTERED_IN == 1) ? r_exponent       : r_exponent_i;
    assign priority_encoded_g = (REGISTERED_IN == 1) ? priority_encoded : priority_encoded_i;

    ////////////////////////////////////////////////////////////////
    // Normalize choices
    logic [NORMALIZE_CHOICES - 1 : 0][1 + MANTISSA_WIDTH + BASE_WIDTH + 2 - 1  :  0] normalize_choices;
    logic [1 + MANTISSA_WIDTH + BASE_WIDTH + 2 - 1 : 0] normalize_carry_choice;
    initial begin
        if(MANTISSA_WIDTH < BASE_WIDTH)
            $fatal(1, "MANTISSA_WIDTH must be at least BASE_WIDTH (%0d)", BASE_WIDTH);
    end

    assign normalize_carry_choice = r_mantissa_grs_g >> BASE_WIDTH;
    generate
        // Carry choice: preserve all shifted-out information in sticky.
        assign normalize_choices[NORMALIZE_CHOICES - 1] = {
            normalize_carry_choice[1 + MANTISSA_WIDTH + BASE_WIDTH + 2 - 1 : 1],
            normalize_carry_choice[0] | (|r_mantissa_grs_g[BASE_WIDTH - 1 : 0])
        };
        // rest of choices
        for(genvar i = 1; i < NORMALIZE_CHOICES; i++) begin
            assign normalize_choices[NORMALIZE_CHOICES - 1 - i] = r_mantissa_grs_g << ((i - 1) * BASE_WIDTH);
        end
    endgenerate

    logic [1 + MANTISSA_WIDTH + BASE_WIDTH + 2 - 1  :  0] normalized;
    multistage_mux #(
        .DATA_WIDTH(1 + MANTISSA_WIDTH + BASE_WIDTH + 2),
        .SIZE(NORMALIZE_CHOICES),
        .REGISTERED_IN(0),
        .LUTX(LUTX),
        .GRADE(GRADE)
    ) normalize_mux (
        .clk_i(clk_i),
        .data_i(normalize_choices),
        .sel_i(priority_encoded_g),
        .data_o(normalized)
    );

    ////////////////////////////////////////////////////////////////
    // Exponent Calculation 1.
    /*
    From proofing we found that the appropriate way to convert the
    priority encoded value to value to add to the exponent is:
    -((-p + K) | C*)
    where
    p  is the priority encoded value
    K  is the constant (NORMALIZE_CHOICES - 2)
    C* is the carry bit replicated to the exponent width (for OR mask).
    Overall take care to make sure bit widths are large enough for signed
    calculations.
    */
    logic [EXPONENT_MAX_WIDTH - 1 : 0] r_exponent_padded;
    logic [EXPONENT_MAX_WIDTH - 1 : 0] r_exponent_padded_p;
    logic [EXPONENT_MAX_WIDTH - 1 : 0] r_priority_encoded_padded;
    logic [EXPONENT_MAX_WIDTH - 1 : 0] or_bit_mask;

    assign or_bit_mask = {EXPONENT_MAX_WIDTH{r_mantissa_grs_g[1 + MANTISSA_WIDTH + BASE_WIDTH + 2 - 1]}};
    always_comb begin
        r_exponent_padded = r_exponent_g;
        r_priority_encoded_padded = priority_encoded_g;

        r_priority_encoded_padded = -r_priority_encoded_padded;                           // -p
        r_priority_encoded_padded = r_priority_encoded_padded + (NORMALIZE_CHOICES - 2);  // -p + K
        r_priority_encoded_padded = r_priority_encoded_padded | or_bit_mask;              // (-p + K) | C*
        r_priority_encoded_padded = -r_priority_encoded_padded;                           // -((-p + K) | C*)

        r_exponent_padded = r_exponent_padded + r_priority_encoded_padded;  // exponent + (-((-p + K) | C*)), add to the exponent
        // since the number of bits for the exponent is small, we hope the synthesizer does a good job at optimizing this logic
    end

    pipe #(
        .DATA_WIDTH(EXPONENT_MAX_WIDTH),
        .LATENCY(MULTISTAGE_MUX_LATENCY)
    ) r_exponent_padded_pipe (
        .clk_i(clk_i),
        .data_i(r_exponent_padded),
        .data_o(r_exponent_padded_p)
    );

    logic r_sign_p;
    pipe #(
        .DATA_WIDTH(1),
        .LATENCY(MULTISTAGE_MUX_LATENCY)
    ) r_sign_pipe (
        .clk_i(clk_i),
        .data_i(r_sign_g),
        .data_o(r_sign_p)
    );

    ////////////////////////////////////////////////////////////////
    // Round & Post-normalize (bit masking)
    logic [1 + MANTISSA_WIDTH + BASE_WIDTH + 2 - 1 : 0] normalized_reg;
    logic [EXPONENT_MAX_WIDTH - 1 : 0] r_exponent_padded_p_reg;
    logic r_sign_p_reg;

    logic [1 + MANTISSA_WIDTH + BASE_WIDTH + 2 - 1 : 0] normalized_g;
    logic [EXPONENT_MAX_WIDTH - 1 : 0] r_exponent_padded_p_g;
    logic r_sign_p_g;

    always@(posedge clk_i) begin
        normalized_reg          <= normalized;
        r_exponent_padded_p_reg <= r_exponent_padded_p;
        r_sign_p_reg            <= r_sign_p;
    end

    assign normalized_g          = (REGISTERED_ROUND == 1) ? normalized_reg          : normalized;
    assign r_exponent_padded_p_g = (REGISTERED_ROUND == 1) ? r_exponent_padded_p_reg : r_exponent_padded_p;
    assign r_sign_p_g            = (REGISTERED_ROUND == 1) ? r_sign_p_reg            : r_sign_p;

    logic guard;
    logic round;
    logic sticky_sticky;
    logic lsb;
    logic msb;
    assign guard =          normalized_g[BASE_WIDTH + 1 + 1 - 1];
    assign round =          normalized_g[BASE_WIDTH + 1 + 1 - 2];
    // we expect this range to be small, so a dedicated reduction OR tree is unecessary
    assign sticky_sticky = |normalized_g[BASE_WIDTH + 1 + 1 - 3 : 0];
    assign lsb           =  normalized_g[BASE_WIDTH + 1 + 1];
    assign msb           =  normalized_g[1 + MANTISSA_WIDTH + BASE_WIDTH + 2 - 2];

    logic [1 + BASE_WIDTH + 1 + 1 - 1 : 0]                round_bits; 
    logic [1 + MANTISSA_WIDTH + BASE_WIDTH + 2 - 1  :  0] normalized_rounded;
    logic [EXPONENT_MAX_WIDTH - 1 : 0]                    post_normalized_exponent;
    logic                                                 carry;

    logic                                                 overflow;  // NaN, INF
    logic                                                 underflow; // result is 0
    logic                                                 subnormal; // result is 0
    
    logic [MANTISSA_WIDTH - 1 : 0] subnormal_underflow_mantissa_bit_mask;


    logic                          final_sign;
    logic [EXPONENT_WIDTH - 1 : 0] final_exponent;
    logic [MANTISSA_WIDTH - 1 : 0] final_mantissa;
    

    //increment = guard & (round | sticky_sticky | lsb)
    always_comb begin
        final_sign = r_sign_p_g;

        // round
        round_bits = '0;
        round_bits[1 + BASE_WIDTH + 1 + 1 - 1] = guard & (round | sticky_sticky | lsb);
        normalized_rounded = normalized_g;
        normalized_rounded = normalized_rounded +  round_bits;

        // check carry
        carry = normalized_rounded[1 + MANTISSA_WIDTH + BASE_WIDTH + 2 - 1];

        // A rounding carry leaves the other retained mantissa bits zero.
        final_mantissa = normalized_rounded[1 + MANTISSA_WIDTH + BASE_WIDTH + 2 - 2 : BASE_WIDTH + 2];
        final_mantissa[POST_NORMALIZE_CARRY_INDEX] = final_mantissa[POST_NORMALIZE_CARRY_INDEX] | carry;

        // adjust exponent in case of carry
        post_normalized_exponent = r_exponent_padded_p_g;
        if(carry) begin
            post_normalized_exponent = post_normalized_exponent + 1;
        end

        // exponent conditions: Overflow, Subnormal, Underflow
        overflow = 0;
        subnormal = 0;
        underflow = 0;

        // Exponents above the field range always overflow. At the maximum
        // exponent, mantissa MSB=1 is the reserved NaN/Inf representation.
        if((!post_normalized_exponent[EXPONENT_MAX_WIDTH - 1]) &&
            ((post_normalized_exponent > EXPONENT_MAX_VALUE) ||
             ((post_normalized_exponent == EXPONENT_MAX_VALUE) && final_mantissa[MANTISSA_WIDTH - 1]))) begin
            overflow = 1;
        end

        // if 0
        if((post_normalized_exponent == 0) &&
           (!final_mantissa[MANTISSA_WIDTH - 1])) begin
            subnormal = 1;
        end

        // if negative
        if(post_normalized_exponent[EXPONENT_MAX_WIDTH - 1]) begin
            underflow = 1;
        end

        subnormal_underflow_mantissa_bit_mask = '1;

        if(subnormal | underflow) begin
            subnormal_underflow_mantissa_bit_mask = '0;
            post_normalized_exponent = '0;
            
        end else if(overflow) begin
            post_normalized_exponent = EXPONENT_MAX_VALUE;
            final_mantissa[MANTISSA_WIDTH - 1] = 1;
        end

        final_exponent = post_normalized_exponent[EXPONENT_WIDTH - 1 : 0];
        final_mantissa = final_mantissa & subnormal_underflow_mantissa_bit_mask;

        // A zero leading radix digit denotes zero after normalization.
        // A rounding carry supplies a new leading digit during post-normalization.
        if(!carry && (normalized_rounded[1 + MANTISSA_WIDTH + BASE_WIDTH + 2 - 2 -: BASE_WIDTH] == '0)) begin
            final_exponent = '0;
        end
    end

    assign sum_o = {final_sign, final_exponent, final_mantissa};

endmodule


