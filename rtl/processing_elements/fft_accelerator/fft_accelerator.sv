/*
FFT accelerator: request reader -> shared ABFP multiplier -> two shared ABFP
adders -> two-write serializer. Sample/twiddle memories are connected externally.

Memory ports:
- One sample read port and one independent sample write port are required; use
  simple dual-port memory or equivalent. A single shared read/write port cannot
  accept this module's overlapping read and write traffic.
- Each sample/twiddle word is {real, imaginary}; each component uses
  DATA_WIDTH = 1 + EXPONENT_WIDTH + MANTISSA_WIDTH ABFP bits.
- READ_LATENCY >=1 is the common sample/twiddle latency from command presentation
  after an edge to returned data after a later edge. Include all memory stages.
- WRITE_LATENCY >=1 is command presentation to actual memory commitment. This
  affects final completion timing, not the writer's output command register.
- There is no memory backpressure. Twiddle entry k must contain W_N**k for the
  runtime FFT size N, including any externally required ROM address scaling.

Runtime controls:
- fft_point_size_i is a power of two N>=2, fitting both sample and twiddle memory.
  fft_whole_iterations_i is a positive count M with M*N<=2**SAMPLES_ADDR_WIDTH.
- Hold configuration stable before go_i and throughout busy_o. go_i is level
  sensitive; lower it before completion to avoid requesting another run.
- The reader uses iterative radix-2 DIT ordering. Supply bit-reversed input
  samples within each N-point block for natural-order FFT outputs. This wrapper
  performs no bit-reversal permutation or output scaling.
- busy_o includes request generation and the final write drain. A high go_i
  while busy is not queued. fft_done_o is a one-clock pulse after all requested
  writes have committed (or at reader completion if the schedule finishes later).

Latency and address alignment:
- Let R=READ_LATENCY, Lm=fft_multiplier_core LATENCY, La=fft_adder_core LATENCY.
  A B/W read command presented after C is sampled by the multiplier at C+R+1.
  The adder samples its early multiplier strobe at C+R+Lm+2; the writer samples
  the completed adder bundle at C+R+Lm+La+3.
- ADDRESS_PIPE_LATENCY=R+Lm+La+2 presents B before that writer edge and A one
  clock later. The same delayed address stream feeds both writer address inputs.
- LATENCY=R+Lm+La+3 is B-read presentation to B/Y1-write presentation. A/Y0 is
  presented one clock later and committed WRITE_LATENCY clocks after that.
  WRITE_COMMIT_LATENCY=R+Lm+La+4+WRITE_LATENCY reaches the final A commitment.
- II_CYCLES>=4 preserves the arithmetic cores' minimum bundle interval.

In-place stage dependencies:
- The reader retains its request-only behavior: no stage waits, dependency
  interlocks or forwarding are added here. Correct address delays alone do not
  make arbitrary multi-stage in-place FFT schedules safe at II_CYCLES=4.
- A conservative bound for all supported N is II_CYCLES>=WRITE_COMMIT_LATENCY:
  every butterfly's writes then commit before the next butterfly's reads are
  sampled. Smaller intervals require a separately established dependency-safe
  schedule or memory architecture. Sample read/write collisions are undefined.

Reset:
- RESET_PIPELINE_DEPTH>=0 sets the same delay for separate active-high synchronous
  reset pipelines for the reader, multiplier, adder, writer and wrapper controls.
  Hold rst_i high for at least RESET_HOLD_CYCLES rising edges, where
  RESET_HOLD_CYCLES=max(RESET_PIPELINE_DEPTH+2, WRITE_LATENCY). This covers the
  reader's additional registered reset and outstanding external write stages.
- Raw and delayed reset suppress external enables/completion; internal control
  and completion pipelines clear. Data, addresses and memory contents are not
  reset. Restart only after reset has been sampled low through the reset pipe
  and the reader's own input register. Reset can leave partial memory updates.

Arithmetic parameters:
- BASE is a power of two >=2; EXPONENT_WIDTH>=1; MANTISSA_WIDTH>=log2(BASE).
  LUTX>=3 and GRADE=1 or 2 configure the existing arithmetic trees.
- REGSITERED_MULTIPLIER (spelling retained) and REGISTERED_NORMALIZE configure
  the shared multiplier. The eleven remaining REGISTERED_* options configure
  both child adders. All flags are binary and retain their child-module meanings.
*/

import constant_functions_pkg::*;

module fft_accelerator #(
    parameter BASE,
    parameter EXPONENT_WIDTH,
    parameter MANTISSA_WIDTH,
    parameter SAMPLES_ADDR_WIDTH,
    parameter TWIDDLES_ADDR_WIDTH,
    parameter II_CYCLES = 4,
    parameter READ_LATENCY = 1,
    parameter WRITE_LATENCY = 1,
    parameter RESET_PIPELINE_DEPTH = 1,
    parameter LUTX = 6,
    parameter GRADE = 1,
    parameter REGSITERED_MULTIPLIER = 1,
    parameter REGISTERED_NORMALIZE = 1,
    parameter REGISTERED_SWAP_IN = 1,
    parameter REGISTERED_SWAP_MUX = 1,
    parameter REGISTERED_ALIGN_STICKY_IN = 1,
    parameter REGISTERED_ALIGN_EXPONENT_MUX = 1,
    parameter REGISTERED_ALIGN_MUX = 1,
    parameter REGISTERED_ADD_CONVERT = 1,
    parameter REGISTERED_ADD_CONVERT_CONVERT = 1,
    parameter REGISTERED_PRIORITY_ENCODE = 1,
    parameter REGISTERED_PRIORITY_ENCODE_ENCODER = 1,
    parameter REGISTERED_NORMALIZE_ROUND_POST_NORMALIZE = 1,
    parameter REGISTERED_NORMALIZE_ROUND_POST_NORMALIZE_ROUND = 1,

    ////////////////////////////////////////////////////////////////
    // Globally Defined Locally Set Parameters
    localparam DATA_WIDTH = fft_multiplier_core_DATA_WIDTH(EXPONENT_WIDTH, MANTISSA_WIDTH),
    localparam COMPLEX_DATA_WIDTH = fft_accelerator_COMPLEX_DATA_WIDTH(EXPONENT_WIDTH, MANTISSA_WIDTH),
    localparam MULTIPLIER_LATENCY = fft_multiplier_core_LATENCY(MANTISSA_WIDTH, REGSITERED_MULTIPLIER, REGISTERED_NORMALIZE, LUTX, GRADE),
    localparam ADDER_LATENCY = fft_adder_core_LATENCY(
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
    localparam RESET_HOLD_CYCLES = fft_accelerator_RESET_HOLD_CYCLES(RESET_PIPELINE_DEPTH, WRITE_LATENCY),
    localparam ADDRESS_PIPE_LATENCY = fft_accelerator_ADDRESS_PIPE_LATENCY(
        BASE,
        MANTISSA_WIDTH,
        LUTX,
        GRADE,
        REGSITERED_MULTIPLIER,
        REGISTERED_NORMALIZE,
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
        REGISTERED_NORMALIZE_ROUND_POST_NORMALIZE_ROUND,
        READ_LATENCY
    ),
    localparam LATENCY = fft_accelerator_LATENCY(
        BASE,
        MANTISSA_WIDTH,
        LUTX,
        GRADE,
        REGSITERED_MULTIPLIER,
        REGISTERED_NORMALIZE,
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
        REGISTERED_NORMALIZE_ROUND_POST_NORMALIZE_ROUND,
        READ_LATENCY
    ),
    localparam WRITE_COMMIT_LATENCY = fft_accelerator_WRITE_COMMIT_LATENCY(
        BASE,
        MANTISSA_WIDTH,
        LUTX,
        GRADE,
        REGSITERED_MULTIPLIER,
        REGISTERED_NORMALIZE,
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
        REGISTERED_NORMALIZE_ROUND_POST_NORMALIZE_ROUND,
        READ_LATENCY,
        WRITE_LATENCY
    ),
    localparam DRAIN_LATENCY = fft_accelerator_DRAIN_LATENCY(
        BASE,
        MANTISSA_WIDTH,
        LUTX,
        GRADE,
        REGSITERED_MULTIPLIER,
        REGISTERED_NORMALIZE,
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
        REGISTERED_NORMALIZE_ROUND_POST_NORMALIZE_ROUND,
        READ_LATENCY,
        WRITE_LATENCY,
        II_CYCLES
    )
) (
    input                                      clk_i,
    input                                      rst_i,
    input                                      go_i,
    input  [SAMPLES_ADDR_WIDTH : 0]             fft_point_size_i,
    input  [SAMPLES_ADDR_WIDTH - 1 : 0]         fft_whole_iterations_i,
    output                                     busy_o,
    output                                     fft_done_o,

    output [SAMPLES_ADDR_WIDTH - 1 : 0]         samples_rd_addr_o,
    output                                     samples_rd_en_o,
    input  [COMPLEX_DATA_WIDTH - 1 : 0]         samples_rd_data_i,
    output [SAMPLES_ADDR_WIDTH - 1 : 0]         samples_wr_addr_o,
    output [COMPLEX_DATA_WIDTH - 1 : 0]         samples_wr_data_o,
    output                                     samples_wr_en_o,

    output [TWIDDLES_ADDR_WIDTH - 1 : 0]        twiddles_rd_addr_o,
    output                                     twiddles_rd_en_o,
    input  [COMPLEX_DATA_WIDTH - 1 : 0]         twiddles_rd_data_i
);
    ////////////////////////////////////////////////////////////////
    // Dedicated equal-depth reset pipelines for each child and wrapper controls.
    logic reader_rst_p, multiplier_rst_p, adder_rst_p, writer_rst_p;
    logic control_rst_p, reset_active;
    pipe #(.DATA_WIDTH(1), .LATENCY(RESET_PIPELINE_DEPTH)) reader_reset_pipe (
        .clk_i(clk_i), .data_i(rst_i), .data_o(reader_rst_p)
    );
    pipe #(.DATA_WIDTH(1), .LATENCY(RESET_PIPELINE_DEPTH)) multiplier_reset_pipe (
        .clk_i(clk_i), .data_i(rst_i), .data_o(multiplier_rst_p)
    );
    pipe #(.DATA_WIDTH(1), .LATENCY(RESET_PIPELINE_DEPTH)) adder_reset_pipe (
        .clk_i(clk_i), .data_i(rst_i), .data_o(adder_rst_p)
    );
    pipe #(.DATA_WIDTH(1), .LATENCY(RESET_PIPELINE_DEPTH)) writer_reset_pipe (
        .clk_i(clk_i), .data_i(rst_i), .data_o(writer_rst_p)
    );
    pipe #(.DATA_WIDTH(1), .LATENCY(RESET_PIPELINE_DEPTH)) control_reset_pipe (
        .clk_i(clk_i), .data_i(rst_i), .data_o(control_rst_p)
    );
    assign reset_active = rst_i || control_rst_p;

    ////////////////////////////////////////////////////////////////
    // Reader: B/W first, A on the following clock.
    logic reader_go, reader_busy, reader_done;
    logic sample_read_enable, twiddle_read_enable;
    // The multiplier generates its own A sample clock from the preceding B/W
    // token; reader a_valid is retained here to make that alignment visible.
    logic a_valid, b_valid, w_valid;
    logic [SAMPLES_ADDR_WIDTH - 1 : 0] read_addr, write_addr_p;
    assign reader_go = go_i && !busy_o && !reset_active;
    assign samples_rd_addr_o = read_addr;
    assign samples_rd_en_o = sample_read_enable && !reset_active;
    assign twiddles_rd_en_o = twiddle_read_enable && !reset_active;
    fsm_fft_reader #(
        .DATA_WIDTH(COMPLEX_DATA_WIDTH), .SAMPLES_ADDR_WIDTH(SAMPLES_ADDR_WIDTH),
        .TWIDDLES_ADDR_WIDTH(TWIDDLES_ADDR_WIDTH), .II_CYCLES(II_CYCLES), .READ_LATENCY(READ_LATENCY)
    ) reader (
        .clk_i(clk_i), .rst_i(reader_rst_p), .go_i(reader_go),
        .fft_point_size_i(fft_point_size_i), .fft_whole_iterations_i(fft_whole_iterations_i),
        .a_b_rd_addr_o(read_addr), .a_b_rd_en_o(sample_read_enable),
        .a_valid_o(a_valid), .b_valid_o(b_valid),
        .w_rd_addr_o(twiddles_rd_addr_o), .w_rd_en_o(twiddle_read_enable), .w_valid_o(w_valid),
        .busy_o(reader_busy), .fft_done_o(reader_done)
    );

    ////////////////////////////////////////////////////////////////
    // Both A and B use the sample read bus at their respective sampling clocks.
    logic [DATA_WIDTH - 1 : 0] sample_real, sample_imag, twiddle_real, twiddle_imag;
    logic [DATA_WIDTH - 1 : 0] wrbr, wibi, wrbi, wibr, ar, ai;
    logic multiplier_valid, adder_valid;
    logic [DATA_WIDTH - 1 : 0] y0r, y0i, y1r, y1i;
    assign {sample_real, sample_imag} = samples_rd_data_i;
    assign {twiddle_real, twiddle_imag} = twiddles_rd_data_i;
    fft_multiplier_core #(
        .BASE(BASE),
        .EXPONENT_WIDTH(EXPONENT_WIDTH),
        .MANTISSA_WIDTH(MANTISSA_WIDTH),
        .REGSITERED_MULTIPLIER(REGSITERED_MULTIPLIER),
        .REGISTERED_NORMALIZE(REGISTERED_NORMALIZE),
        .LUTX(LUTX),
        .GRADE(GRADE)
    ) multiplier (
        .clk_i(clk_i), .rst_i(multiplier_rst_p),
        .wr_i(twiddle_real), .wi_i(twiddle_imag),
        .br_i(sample_real), .bi_i(sample_imag), .ar_i(sample_real), .ai_i(sample_imag),
        .w_b_valid_i(b_valid && w_valid && !reset_active),
        .wrbr_o(wrbr), .wibi_o(wibi), .wrbi_o(wrbi), .wibr_o(wibr),
        .ar_o(ar), .ai_o(ai), .valid_o(multiplier_valid)
    );
    fft_adder_core #(
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
    ) adder (
        .clk_i(clk_i), .rst_i(adder_rst_p), .valid_i(multiplier_valid && !reset_active),
        .wrbr_i(wrbr), .wibi_i(wibi), .wrbi_i(wrbi), .wibr_i(wibr), .ar_i(ar), .ai_i(ai),
        .y0r_o(y0r), .y0i_o(y0i), .y1r_o(y1r), .y1i_o(y1i), .valid_o(adder_valid)
    );

    ////////////////////////////////////////////////////////////////
    // Delay the whole address stream: writer samples B then A on adjacent edges.
    logic write_enable;
    pipe #(.DATA_WIDTH(SAMPLES_ADDR_WIDTH), .LATENCY(ADDRESS_PIPE_LATENCY)) address_pipe (
        .clk_i(clk_i), .data_i(read_addr), .data_o(write_addr_p)
    );
    fsm_fft_writer #(.DATA_WIDTH(COMPLEX_DATA_WIDTH), .ADDR_WIDTH(SAMPLES_ADDR_WIDTH)) writer (
        .clk_i(clk_i), .rst_i(writer_rst_p), .valid_i(adder_valid && !reset_active),
        .a_wr_addr_i(write_addr_p), .b_wr_addr_i(write_addr_p),
        .y0_i({y0r, y0i}), .y1_i({y1r, y1i}),
        .wr_addr_o(samples_wr_addr_o), .wr_data_o(samples_wr_data_o), .wr_en_o(write_enable)
    );
    assign samples_wr_en_o = write_enable && !reset_active;

    ////////////////////////////////////////////////////////////////
    // Extend busy/done through the final memory commitment. Reset all tokens,
    // so holding reset need not flush a long, unreset done-delay shift register.
    generate
        if(DRAIN_LATENCY == 0) begin : gen_completion_bypass
            assign busy_o = reader_busy && !reset_active;
            assign fft_done_o = reader_done && !reset_active;
        end else begin : gen_completion_pipe
            logic [DRAIN_LATENCY - 1 : 0] busy_tail, done_tail;
            always @(posedge clk_i) begin
                if(control_rst_p) begin
                    busy_tail <= '0;
                    done_tail <= '0;
                end else begin
                    busy_tail[0] <= reader_busy;
                    done_tail[0] <= reader_done;
                    for(int i = 1; i < DRAIN_LATENCY; i++) begin
                        busy_tail[i] <= busy_tail[i - 1];
                        done_tail[i] <= done_tail[i - 1];
                    end
                end
            end
            assign busy_o = (reader_busy || (|busy_tail)) && !reset_active;
            assign fft_done_o = done_tail[DRAIN_LATENCY - 1] && !reset_active;
        end
    endgenerate
endmodule
