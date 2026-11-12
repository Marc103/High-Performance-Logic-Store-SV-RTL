`ifndef FSM_FFT_READER_INF
`define FSM_FFT_READER_INF
import constant_functions_pkg::*;

interface fsm_fft_reader_inf #(
    parameter DATA_WIDTH,
    parameter SAMPLES_ADDR_WIDTH,
    parameter TWIDDLES_ADDR_WIDTH,
    parameter II_CYCLES,
    parameter READ_LATENCY
) (input clk_i);
    logic rst_i = 1;
    logic [SAMPLES_ADDR_WIDTH : 0] fft_point_size_i = 2;
    logic [SAMPLES_ADDR_WIDTH - 1 : 0] fft_whole_iterations_i = 1;
    logic go_i = 0;
    logic [SAMPLES_ADDR_WIDTH - 1 : 0] a_b_rd_addr_o;
    logic a_b_rd_en_o, a_valid_o, b_valid_o;
    logic [TWIDDLES_ADDR_WIDTH - 1 : 0] w_rd_addr_o;
    logic w_rd_en_o, w_valid_o, busy_o, fft_done_o;
    logic start_sequence = 0, end_sequence = 0, end_last_sequence = 0, idle = 1;
endinterface
`endif
