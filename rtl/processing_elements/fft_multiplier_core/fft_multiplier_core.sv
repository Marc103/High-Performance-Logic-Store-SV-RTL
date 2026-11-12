/*
FFT multiplier core, using one alternate-base floating-point multiplier.

Wr, Wi, Br, and Bi are captured together on a rising edge of w_b_valid_i
while idle or while issuing the previous set's final product. Ar and Ai
are sampled on the following clock using the internally generated a_valid.
They may arrive with W/B if held through that following sample clock.
The core issues WrBr, WiBi, WrBi, WiBr on four consecutive clocks after
the W/B capture. There is no backpressure: W/B groups must be at least
four clocks apart, and w_b_valid_i must go low between updates.
For example, W/B may arrive on clocks 0, 4, 8 and A is sampled on 1, 5, 9.

Individual product registers update as their results arrive. Ar/Ai update
with the second product, WiBi, at multiplier latency + 2 clocks after W/B
capture. valid_o strobes on that same edge, qualifying WrBr, WiBi, Ar, and Ai
for the first downstream adder operation. WrBi and WiBr update one and two
clocks later; valid_o does not qualify all six outputs at once.
Outputs hold their values between updates. The downstream operations
Tr = WrBr - WiBi and Ti = WrBi + WiBr are outside this core.

LATENCY is measured from the W/B capture clock to the clock asserting
valid_o. Reset is synchronous, clears control/valid state, and discards pending
inputs and in-flight results. Datapath registers are not reset; data is meaningful
only with the corresponding validity. The ABFP format and arithmetic rules are inherited
from alternate_base_fp_multiplier.
REGSITERED_MULTIPLIER and REGISTERED_NORMALIZE configure that multiplier;
the input holding registers and the output holding registers are always present.

BASE [2,4,8,16,...]:
- ABFP numeric radix; must be a power of two >= 2. This is independent of FFT radix.

EXPONENT_WIDTH [>= 1]:
- Exponent-field bits. The ABFP bias is 2**(EXPONENT_WIDTH - 1) - 1.

MANTISSA_WIDTH [>= log2(BASE)]:
- Explicit mantissa bits, excluding sign/exponent; there is no implicit leading bit.
- All six input/output words use 1 + EXPONENT_WIDTH + MANTISSA_WIDTH bits.

REGSITERED_MULTIPLIER [0,1]:
- Enable the shared ABFP multiplier's input register stage, after operand selection.
- Maps to the child multiplier's REGISTERED_IN parameter. Core W/B capture,
  A alignment, and output holding registers remain present for either setting.
- REGISTERED_IN is reserved for direct registration of a module's *_i signals;
  this core option controls an internal arithmetic stage instead.

REGISTERED_NORMALIZE [0,1]:
- Register the shared multiplier's product and associated fields before its
  normalize/round/post-normalize logic.

LUTX [>= 3]:
- LUT input count used to size the multiplier's sticky-OR reduction tree.

GRADE [1,2]:
- Combinational LUT levels grouped per reduction-tree stage; the group size is
  LUTX**GRADE. Changing LUTX/GRADE can change the internal multiplier latency.

All register flags are binary. MULTIPLIER_LATENCY includes the selected child
registers and internal sticky-tree registers. A_PIPE_LATENCY is that latency + 1;
the public LATENCY to the WiBi/A early strobe is that latency + 2. These choices
change companion delays automatically; the minimum bundle spacing stays four clocks.
*/

import constant_functions_pkg::*;

module fft_multiplier_core #(
    parameter BASE,
    parameter EXPONENT_WIDTH,
    parameter MANTISSA_WIDTH,
    parameter REGSITERED_MULTIPLIER,
    parameter REGISTERED_NORMALIZE,
    parameter LUTX,
    parameter GRADE,

    ////////////////////////////////////////////////////////////////
    // Globally Defined Locally Set Parameters
    localparam DATA_WIDTH = fft_multiplier_core_DATA_WIDTH(EXPONENT_WIDTH, MANTISSA_WIDTH),
    localparam MULTIPLIER_LATENCY = alternate_base_fp_multiplier_LATENCY(
        MANTISSA_WIDTH, REGSITERED_MULTIPLIER, REGISTERED_NORMALIZE, LUTX, GRADE
    ),
    localparam A_PIPE_LATENCY = fft_multiplier_core_A_PIPE_LATENCY(
        MANTISSA_WIDTH, REGSITERED_MULTIPLIER, REGISTERED_NORMALIZE, LUTX, GRADE
    ),
    localparam LATENCY = fft_multiplier_core_LATENCY(
        MANTISSA_WIDTH, REGSITERED_MULTIPLIER, REGISTERED_NORMALIZE, LUTX, GRADE
    )
) (
    input clk_i,
    input rst_i,
    input [DATA_WIDTH - 1 : 0] wr_i,
    input [DATA_WIDTH - 1 : 0] wi_i,
    input [DATA_WIDTH - 1 : 0] br_i,
    input [DATA_WIDTH - 1 : 0] bi_i,
    input [DATA_WIDTH - 1 : 0] ar_i,
    input [DATA_WIDTH - 1 : 0] ai_i,
    input w_b_valid_i,
    output logic [DATA_WIDTH - 1 : 0] wrbr_o,
    output logic [DATA_WIDTH - 1 : 0] wibi_o,
    output logic [DATA_WIDTH - 1 : 0] wrbi_o,
    output logic [DATA_WIDTH - 1 : 0] wibr_o,
    output logic [DATA_WIDTH - 1 : 0] ar_o,
    output logic [DATA_WIDTH - 1 : 0] ai_o,
    output logic valid_o
);
    logic [DATA_WIDTH - 1 : 0] wr, wi, br, bi;
    logic w_b_valid_previous;
    logic w_b_strobe;
    logic w_b_capture;
    logic a_valid;

    assign w_b_strobe = w_b_valid_i && !w_b_valid_previous;

    typedef enum logic [2:0] {
        IDLE,
        ISSUE_WRBR,
        ISSUE_WIBI,
        ISSUE_WRBI,
        ISSUE_WIBR
    } state_t;
    state_t state;

    // The final issue consumes the old registers before a new W/B capture.
    assign w_b_capture = w_b_strobe && ((state == IDLE) || (state == ISSUE_WIBR));
    // The following first issue clock samples Ar and Ai.
    assign a_valid = (state == ISSUE_WRBR) && !rst_i;

    always @(posedge clk_i) begin
        if(rst_i) begin
            w_b_valid_previous <= 0;
            state <= IDLE;
        end else begin
            w_b_valid_previous <= w_b_valid_i;
            if(w_b_capture) begin
                wr <= wr_i;
                wi <= wi_i;
                br <= br_i;
                bi <= bi_i;
            end
            case(state)
                IDLE: begin
                    if(w_b_capture) state <= ISSUE_WRBR;
                end
                ISSUE_WRBR: state <= ISSUE_WIBI;
                ISSUE_WIBI: state <= ISSUE_WRBI;
                ISSUE_WRBI: state <= ISSUE_WIBR;
                ISSUE_WIBR: state <= w_b_capture ? ISSUE_WRBR : IDLE;
                default: state <= IDLE;
            endcase
        end
    end

    ////////////////////////////////////////////////////////////////
    // Share one multiplier across the four products.
    logic [DATA_WIDTH - 1 : 0] multiplier_a;
    logic [DATA_WIDTH - 1 : 0] multiplier_b;
    logic [DATA_WIDTH - 1 : 0] product;
    logic issue_valid;
    logic [1:0] issue_selector;
    logic result_valid;
    logic [1:0] result_selector;

    always_comb begin
        multiplier_a = wr;
        multiplier_b = br;
        issue_valid = a_valid;
        issue_selector = 2'd0;
        case(state)
            ISSUE_WIBI: begin
                multiplier_a = wi;
                multiplier_b = bi;
                issue_valid = !rst_i;
                issue_selector = 2'd1;
            end
            ISSUE_WRBI: begin
                multiplier_b = bi;
                issue_valid = !rst_i;
                issue_selector = 2'd2;
            end
            ISSUE_WIBR: begin
                multiplier_a = wi;
                issue_valid = !rst_i;
                issue_selector = 2'd3;
            end
            default: begin end
        endcase
    end

    alternate_base_fp_multiplier #(
        .BASE(BASE),
        .EXPONENT_WIDTH(EXPONENT_WIDTH),
        .MANTISSA_WIDTH(MANTISSA_WIDTH),
        .REGISTERED_IN(REGSITERED_MULTIPLIER),
        .REGISTERED_NORMALIZE(REGISTERED_NORMALIZE),
        .LUTX(LUTX),
        .GRADE(GRADE)
    ) multiplier_inst (
        .clk_i(clk_i),
        .a_i(multiplier_a),
        .b_i(multiplier_b),
        .product_o(product)
    );

    pipe #(.DATA_WIDTH(2), .LATENCY(MULTIPLIER_LATENCY)) result_selector_pipe (
        .clk_i(clk_i), .data_i(issue_selector), .data_o(result_selector)
    );

    // Reset only the validity pipeline; invalid arithmetic results are ignored.
    generate
        if(MULTIPLIER_LATENCY == 0) begin : gen_valid_bypass
            assign result_valid = issue_valid;
        end else begin : gen_valid_pipe
            logic [MULTIPLIER_LATENCY - 1 : 0] valid;
            always @(posedge clk_i) begin
                if(rst_i) begin
                    valid <= '0;
                end else begin
                    valid[0] <= issue_valid;
                    for(int i = 1; i < MULTIPLIER_LATENCY; i++) begin
                        valid[i] <= valid[i - 1];
                    end
                end
            end
            assign result_valid = valid[MULTIPLIER_LATENCY - 1];
        end
    endgenerate

    ////////////////////////////////////////////////////////////////
    // Align A with WiBi, the second product, including its output holding register.
    logic [DATA_WIDTH - 1 : 0] ar_p;
    logic [DATA_WIDTH - 1 : 0] ai_p;
    logic [A_PIPE_LATENCY - 1 : 0] a_valid_l;
    logic a_valid_p;
    pipe #(.DATA_WIDTH(DATA_WIDTH), .LATENCY(A_PIPE_LATENCY)) ar_pipe (
        .clk_i(clk_i), .data_i(ar_i), .data_o(ar_p)
    );
    pipe #(.DATA_WIDTH(DATA_WIDTH), .LATENCY(A_PIPE_LATENCY)) ai_pipe (
        .clk_i(clk_i), .data_i(ai_i), .data_o(ai_p)
    );

    // A arrives on the first issue clock. Delay its valid with the raw data.
    always @(posedge clk_i) begin
        if(rst_i) begin
            a_valid_l <= '0;
        end else begin
            a_valid_l[0] <= a_valid;
            for(int i = 1; i < A_PIPE_LATENCY; i++) begin
                a_valid_l[i] <= a_valid_l[i - 1];
            end
        end
    end
    assign a_valid_p = a_valid_l[A_PIPE_LATENCY - 1];

    always @(posedge clk_i) begin
        if(rst_i) begin
            valid_o <= 0;
        end else begin
            valid_o <= 0;
            if(a_valid_p) begin
                ar_o <= ar_p;
                ai_o <= ai_p;
            end
            if(result_valid) begin
                case(result_selector)
                    2'd0: wrbr_o <= product;
                    2'd1: begin
                        wibi_o <= product;
                        valid_o <= 1;
                    end
                    2'd2: wrbi_o <= product;
                    2'd3: wibr_o <= product;
                endcase
            end
        end
    end
endmodule
