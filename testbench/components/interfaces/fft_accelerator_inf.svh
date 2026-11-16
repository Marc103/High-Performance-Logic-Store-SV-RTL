`ifndef FFT_ACCELERATOR_INF
`define FFT_ACCELERATOR_INF
import constant_functions_pkg::*;
interface fft_accelerator_inf #(
    parameter BASE = 16,
    parameter EXPONENT_WIDTH = 6,
    parameter MANTISSA_WIDTH = 25,
    parameter SAMPLES_ADDR_WIDTH = 15,
    parameter TWIDDLES_ADDR_WIDTH = 14,
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
    parameter II_CYCLES = fft_accelerator_WRITE_COMMIT_LATENCY(
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
    localparam DATA_WIDTH = fft_multiplier_core_DATA_WIDTH(EXPONENT_WIDTH, MANTISSA_WIDTH),
    localparam COMPLEX_DATA_WIDTH = fft_accelerator_COMPLEX_DATA_WIDTH(EXPONENT_WIDTH, MANTISSA_WIDTH)
) (input clk_i);
    logic rst_i=1, go_i=0;
    logic [SAMPLES_ADDR_WIDTH:0] fft_point_size_i=2;
    logic [SAMPLES_ADDR_WIDTH-1:0] fft_whole_iterations_i=1;
    logic busy_o, fft_done_o;
    logic [SAMPLES_ADDR_WIDTH-1:0] samples_rd_addr_o, samples_wr_addr_o;
    logic samples_rd_en_o, samples_wr_en_o;
    logic [COMPLEX_DATA_WIDTH-1:0] samples_rd_data_i, samples_wr_data_o, twiddles_rd_data_i;
    logic [TWIDDLES_ADDR_WIDTH-1:0] twiddles_rd_addr_o;
    logic twiddles_rd_en_o;
    // Memory storage lives in the TB module: virtual-interface access to entire
    // unpacked arrays makes Verilator compare/copy all entries every clock.
    logic commit_en=0;
    logic [SAMPLES_ADDR_WIDTH-1:0] commit_address;
    logic [COMPLEX_DATA_WIDTH-1:0] commit_data;
    longint unsigned clock_count=0;
    always @(posedge clk_i) clock_count <= clock_count+1;
    bit loading=1, start_sequence=0, end_sequence=0, end_last_sequence=0, idle=1;
endinterface
`endif
