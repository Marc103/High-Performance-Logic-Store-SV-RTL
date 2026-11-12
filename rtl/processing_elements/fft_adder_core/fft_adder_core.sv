/*
FFT butterfly adder core using two shared alternate-base floating-point adders.

valid_i is the early strobe from fft_multiplier_core: WrBr, WiBi, Ar, and Ai
are available on its accepted rising edge. WrBi and WiBr must be available
one and two clocks later; Ti is issued on the second later clock.
Input strobes must be sampled low between bundles and be at least four clocks
apart. There is no queue or backpressure; early busy strobes are ignored.

First adder:  Tr = WrBr - WiBi at T; Ti = WrBi + WiBr at T+2.
Let A = ADDER_LATENCY. Tr and Ti are stored at T+A and T+A+2.
Ar/Ai sample at T and are delayed/stored with Tr at T+A.
Second adder issues Y0r, Y1r, Y0i, Y1i at T+A+1 through T+A+4:
    Y0r = Ar + Tr; Y1r = Ar - Tr; Y0i = Ai + Ti; Y1i = Ai - Ti.
This real-pair-first order keeps one bundle per four clocks without waiting
for Ti. Each addition rounds independently using the existing ABFP rules.
Subtraction flips only the packed word's sign bit, including signed zeros.

All four output registers are coherent on valid_o at T+2*A+4. They otherwise
update individually and hold. Reset is synchronous and clears control/valid
state only; datapaths are unreset and may be unknown before their first writes.
All REGISTERED_* flags configure both shared adders identically.

BASE [2,4,8,16,...]:
- ABFP numeric radix; must be a power of two >= 2. This is independent of FFT radix.

EXPONENT_WIDTH [>= 1]:
- Exponent-field bits. The ABFP bias is 2**(EXPONENT_WIDTH - 1) - 1.

MANTISSA_WIDTH [>= log2(BASE)]:
- Explicit mantissa bits, excluding sign/exponent; there is no implicit leading bit.
- All input/output words use 1 + EXPONENT_WIDTH + MANTISSA_WIDTH bits.

LUTX [>= 3]:
- LUT input count used to size the child adders' reduction, priority, and mux trees.

GRADE [1,2]:
- Combinational LUT levels grouped per tree/mux stage. Larger groups can reduce
  internal pipeline depth at the cost of more combinational logic per stage.

The following REGISTERED_* flags are all [0,1] and are forwarded to both adders:

REGISTERED_SWAP_IN:
- Register operands entering the exponent-comparison/swap stage.
REGISTERED_SWAP_MUX:
- Register the operands and comparison decision before the swap-selection muxes.

REGISTERED_ALIGN_STICKY_IN:
- Register operands entering mantissa alignment and sticky-bit generation.
REGISTERED_ALIGN_EXPONENT_MUX:
- Register the exponent difference/comparison used to select the alignment shift.
REGISTERED_ALIGN_MUX:
- Register inputs to the mantissa/sticky alignment mux trees.

REGISTERED_ADD_CONVERT:
- Register aligned operands entering signed mantissa addition/subtraction.
REGISTERED_ADD_CONVERT_CONVERT:
- Register the arithmetic result before conversion back to sign and magnitude.

REGISTERED_PRIORITY_ENCODE:
- Register inputs to leading-radix-digit reduction and priority encoding.
REGISTERED_PRIORITY_ENCODE_ENCODER:
- Register inputs to the priority encoder after the radix-digit OR reductions.

REGISTERED_NORMALIZE_ROUND_POST_NORMALIZE:
- Register inputs to normalization and exponent adjustment.
REGISTERED_NORMALIZE_ROUND_POST_NORMALIZE_ROUND:
- Register the normalized mantissa, adjusted exponent, and sign before rounding.

These flags control arithmetic stages after the core operand muxes. A standalone
REGISTERED_IN name is reserved for direct registration of a module's *_i signals.
ADDER_LATENCY includes the selected registers and internal tree/mux pipelines;
disabling every flag does not necessarily make the arithmetic combinational.
A_PIPE_LATENCY equals ADDER_LATENCY, and public LATENCY is 2*ADDER_LATENCY + 4.
The core's intermediate/output holding registers remain present, and the minimum
bundle spacing stays four clocks for every supported register configuration.
*/

import constant_functions_pkg::*;

module fft_adder_core #(
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
    localparam DATA_WIDTH = fft_adder_core_DATA_WIDTH(EXPONENT_WIDTH, MANTISSA_WIDTH),
    localparam ADDER_LATENCY = alternate_base_fp_adder_LATENCY(
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
    ),
    localparam A_PIPE_LATENCY = fft_adder_core_A_PIPE_LATENCY(
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
    ),
    localparam LATENCY = fft_adder_core_LATENCY(
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
    input rst_i,
    input valid_i,
    input [DATA_WIDTH - 1 : 0] wrbr_i,
    input [DATA_WIDTH - 1 : 0] wibi_i,
    input [DATA_WIDTH - 1 : 0] wrbi_i,
    input [DATA_WIDTH - 1 : 0] wibr_i,
    input [DATA_WIDTH - 1 : 0] ar_i,
    input [DATA_WIDTH - 1 : 0] ai_i,
    output logic [DATA_WIDTH - 1 : 0] y0r_o,
    output logic [DATA_WIDTH - 1 : 0] y0i_o,
    output logic [DATA_WIDTH - 1 : 0] y1r_o,
    output logic [DATA_WIDTH - 1 : 0] y1i_o,
    output logic valid_o
);
    ////////////////////////////////////////////////////////////////
    // First stage: issue the real difference now and imaginary sum two clocks later.
    typedef enum logic [1:0] {INPUT_IDLE, WAIT_TI, ISSUE_TI, INPUT_RECOVER} input_state_t;
    input_state_t input_state;
    logic valid_previous;
    logic accept;
    logic [DATA_WIDTH - 1 : 0] wibi_negated;
    logic [DATA_WIDTH - 1 : 0] first_a, first_b, first_sum;
    logic first_issue_valid, first_issue_selector;
    logic first_result_valid, first_result_selector;
    logic tr_valid, ti_valid;

    assign accept = valid_i && !valid_previous && (input_state == INPUT_IDLE) && !rst_i;
    always @(posedge clk_i) begin
        if(rst_i) begin
            valid_previous <= 0;
            input_state <= INPUT_IDLE;
        end else begin
            valid_previous <= valid_i;
            case(input_state)
                INPUT_IDLE: if(accept) input_state <= WAIT_TI;
                WAIT_TI: input_state <= ISSUE_TI;
                ISSUE_TI: input_state <= INPUT_RECOVER;
                INPUT_RECOVER: input_state <= INPUT_IDLE;
                default: input_state <= INPUT_IDLE;
            endcase
        end
    end

    always_comb begin
        wibi_negated = wibi_i;
        wibi_negated[DATA_WIDTH - 1] = ~wibi_i[DATA_WIDTH - 1];
        first_a = wrbr_i;
        first_b = wibi_negated;
        first_issue_valid = accept;
        first_issue_selector = 0;
        if(input_state == ISSUE_TI) begin
            first_a = wrbi_i;
            first_b = wibr_i;
            first_issue_valid = !rst_i;
            first_issue_selector = 1;
        end
    end

    alternate_base_fp_adder #(
        .BASE(BASE),
        .EXPONENT_WIDTH(EXPONENT_WIDTH),
        .MANTISSA_WIDTH(MANTISSA_WIDTH),
        .LUTX(LUTX),
        .GRADE(GRADE),
        .REGISTERED_SWAP_IN(REGISTERED_SWAP_IN),
        .REGISTERED_SWAP_MUX(REGISTERED_SWAP_MUX),
        .REGISTERED_ALIGN_STICKY_IN(REGISTERED_ALIGN_STICKY_IN),
        .REGISTERED_ALIGN_EXPONENT_MUX(REGISTERED_ALIGN_EXPONENT_MUX),
        .REGISTERED_ALIGN_MUX(REGISTERED_ALIGN_MUX),
        .REGISTERED_ADD_CONVERT(REGISTERED_ADD_CONVERT),
        .REGISTERED_ADD_CONVERT_CONVERT(REGISTERED_ADD_CONVERT_CONVERT),
        .REGISTERED_PRIORITY_ENCODE(REGISTERED_PRIORITY_ENCODE),
        .REGISTERED_PRIORITY_ENCODE_ENCODER(REGISTERED_PRIORITY_ENCODE_ENCODER),
        .REGISTERED_NORMALIZE_ROUND_POST_NORMALIZE(REGISTERED_NORMALIZE_ROUND_POST_NORMALIZE),
        .REGISTERED_NORMALIZE_ROUND_POST_NORMALIZE_ROUND(REGISTERED_NORMALIZE_ROUND_POST_NORMALIZE_ROUND)
    ) first_adder (
        .clk_i(clk_i), .a_i(first_a), .b_i(first_b), .sum_o(first_sum)
    );
    pipe #(.DATA_WIDTH(1), .LATENCY(ADDER_LATENCY)) first_selector_pipe (
        .clk_i(clk_i), .data_i(first_issue_selector), .data_o(first_result_selector)
    );

    ////////////////////////////////////////////////////////////////
    // Intermediate holding registers. The real-result token also qualifies A.
    logic [DATA_WIDTH - 1 : 0] tr, ti, ar, ai;
    logic [DATA_WIDTH - 1 : 0] ar_p, ai_p;
    assign tr_valid = first_result_valid && !first_result_selector;
    assign ti_valid = first_result_valid && first_result_selector;
    pipe #(.DATA_WIDTH(DATA_WIDTH), .LATENCY(A_PIPE_LATENCY)) ar_pipe (
        .clk_i(clk_i), .data_i(ar_i), .data_o(ar_p)
    );
    pipe #(.DATA_WIDTH(DATA_WIDTH), .LATENCY(A_PIPE_LATENCY)) ai_pipe (
        .clk_i(clk_i), .data_i(ai_i), .data_o(ai_p)
    );
    always @(posedge clk_i) begin
        if(!rst_i) begin
            if(tr_valid) begin
                tr <= first_sum;
                ar <= ar_p;
                ai <= ai_p;
            end
            if(ti_valid) ti <= first_sum;
        end
    end

    ////////////////////////////////////////////////////////////////
    // Second stage: two real results, then two imaginary results, with no bubble.
    typedef enum logic [2:0] {
        OUTPUT_IDLE, ISSUE_Y0R, ISSUE_Y1R, ISSUE_Y0I, ISSUE_Y1I
    } output_state_t;
    output_state_t output_state;
    logic [DATA_WIDTH - 1 : 0] selected_t, second_a, second_b, second_sum;
    logic negate_t;
    logic second_issue_valid, second_result_valid;
    logic [1:0] second_issue_selector, second_result_selector;

    always @(posedge clk_i) begin
        if(rst_i) begin
            output_state <= OUTPUT_IDLE;
        end else begin
            case(output_state)
                OUTPUT_IDLE: if(tr_valid) output_state <= ISSUE_Y0R;
                ISSUE_Y0R: output_state <= ISSUE_Y1R;
                ISSUE_Y1R: output_state <= ISSUE_Y0I;
                ISSUE_Y0I: output_state <= ISSUE_Y1I;
                // New Tr/A may be stored while the old final imaginary operation is issued.
                ISSUE_Y1I: output_state <= tr_valid ? ISSUE_Y0R : OUTPUT_IDLE;
                default: output_state <= OUTPUT_IDLE;
            endcase
        end
    end

    always_comb begin
        selected_t = tr;
        second_b = ar;
        negate_t = 0;
        second_issue_valid = 0;
        second_issue_selector = 2'd0;
        case(output_state)
            ISSUE_Y0R: begin
                second_issue_valid = !rst_i;
                second_issue_selector = 2'd0;
            end
            ISSUE_Y1R: begin
                negate_t = 1;
                second_issue_valid = !rst_i;
                second_issue_selector = 2'd1;
            end
            ISSUE_Y0I: begin
                selected_t = ti;
                second_b = ai;
                second_issue_valid = !rst_i;
                second_issue_selector = 2'd2;
            end
            ISSUE_Y1I: begin
                selected_t = ti;
                second_b = ai;
                negate_t = 1;
                second_issue_valid = !rst_i;
                second_issue_selector = 2'd3;
            end
            default: begin end
        endcase
        second_a = selected_t;
        if(negate_t) second_a[DATA_WIDTH - 1] = ~selected_t[DATA_WIDTH - 1];
    end

    alternate_base_fp_adder #(
        .BASE(BASE),
        .EXPONENT_WIDTH(EXPONENT_WIDTH),
        .MANTISSA_WIDTH(MANTISSA_WIDTH),
        .LUTX(LUTX),
        .GRADE(GRADE),
        .REGISTERED_SWAP_IN(REGISTERED_SWAP_IN),
        .REGISTERED_SWAP_MUX(REGISTERED_SWAP_MUX),
        .REGISTERED_ALIGN_STICKY_IN(REGISTERED_ALIGN_STICKY_IN),
        .REGISTERED_ALIGN_EXPONENT_MUX(REGISTERED_ALIGN_EXPONENT_MUX),
        .REGISTERED_ALIGN_MUX(REGISTERED_ALIGN_MUX),
        .REGISTERED_ADD_CONVERT(REGISTERED_ADD_CONVERT),
        .REGISTERED_ADD_CONVERT_CONVERT(REGISTERED_ADD_CONVERT_CONVERT),
        .REGISTERED_PRIORITY_ENCODE(REGISTERED_PRIORITY_ENCODE),
        .REGISTERED_PRIORITY_ENCODE_ENCODER(REGISTERED_PRIORITY_ENCODE_ENCODER),
        .REGISTERED_NORMALIZE_ROUND_POST_NORMALIZE(REGISTERED_NORMALIZE_ROUND_POST_NORMALIZE),
        .REGISTERED_NORMALIZE_ROUND_POST_NORMALIZE_ROUND(REGISTERED_NORMALIZE_ROUND_POST_NORMALIZE_ROUND)
    ) second_adder (
        .clk_i(clk_i), .a_i(second_a), .b_i(second_b), .sum_o(second_sum)
    );
    pipe #(.DATA_WIDTH(2), .LATENCY(ADDER_LATENCY)) second_selector_pipe (
        .clk_i(clk_i), .data_i(second_issue_selector), .data_o(second_result_selector)
    );

    ////////////////////////////////////////////////////////////////
    // Reset only token validity; both arithmetic datapaths and tag/data pipes are unreset.
    generate
        if(ADDER_LATENCY == 0) begin : gen_valid_bypass
            assign first_result_valid = first_issue_valid;
            assign second_result_valid = second_issue_valid;
        end else begin : gen_valid_pipes
            logic [ADDER_LATENCY - 1 : 0] first_valid, second_valid;
            always @(posedge clk_i) begin
                if(rst_i) begin
                    first_valid <= '0;
                    second_valid <= '0;
                end else begin
                    first_valid[0] <= first_issue_valid;
                    second_valid[0] <= second_issue_valid;
                    for(int i = 1; i < ADDER_LATENCY; i++) begin
                        first_valid[i] <= first_valid[i - 1];
                        second_valid[i] <= second_valid[i - 1];
                    end
                end
            end
            assign first_result_valid = first_valid[ADDER_LATENCY - 1];
            assign second_result_valid = second_valid[ADDER_LATENCY - 1];
        end
    endgenerate

    always @(posedge clk_i) begin
        if(rst_i) begin
            valid_o <= 0;
        end else begin
            valid_o <= 0;
            if(second_result_valid) begin
                case(second_result_selector)
                    2'd0: y0r_o <= second_sum;
                    2'd1: y1r_o <= second_sum;
                    2'd2: y0i_o <= second_sum;
                    2'd3: begin
                        y1i_o <= second_sum;
                        valid_o <= 1;
                    end
                endcase
            end
        end
    end
endmodule
