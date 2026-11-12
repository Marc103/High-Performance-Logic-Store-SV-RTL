import constant_functions_pkg::*;

class FsmFftReaderIO #(
    parameter DATA_WIDTH,
    parameter SAMPLES_ADDR_WIDTH,
    parameter TWIDDLES_ADDR_WIDTH,
    parameter II_CYCLES,
    parameter READ_LATENCY,
    parameter RANDOM_TRANSACTIONS = 32,
    localparam DATA_DEPTH = bram_single_port_DATA_DEPTH(SAMPLES_ADDR_WIDTH),
    localparam CYCLES_WIDTH = fsm_fft_reader_CYCLES_WIDTH(II_CYCLES),
    localparam MAX_FFT_LOG2 = min(SAMPLES_ADDR_WIDTH, TWIDDLES_ADDR_WIDTH + 1),
    localparam MAX_FFT_SIZE = 2**MAX_FFT_LOG2,
    localparam MAX_SCHEDULE_CYCLES = (DATA_DEPTH/2)*MAX_FFT_LOG2*II_CYCLES
);
    `FSM_FFT_READER_IO_IN_STRUCT(SAMPLES_ADDR_WIDTH)
    `FSM_FFT_READER_IO_OUT_STRUCT(SAMPLES_ADDR_WIDTH, TWIDDLES_ADDR_WIDTH)
    fsm_fft_reader_io_in_t fsm_fft_reader_io_in_q[$];
    fsm_fft_reader_io_out_t fsm_fft_reader_io_out_q[$];
    // Each item is a clock. Low go/idle clocks still advance requests and valids.
    bit idle[$];
    logic [7:0] error_state[$];
    logic end_last_sequence = 0;
    function new();
    endfunction
endclass
