import constant_functions_pkg::*;

class FsmFftWriterIO #(
    parameter DATA_WIDTH,
    parameter ADDR_WIDTH,
    parameter RANDOM_TRANSACTIONS = 256
);
    `FSM_FFT_WRITER_IO_IN_STRUCT(DATA_WIDTH, ADDR_WIDTH)
    `FSM_FFT_WRITER_IO_OUT_STRUCT(DATA_WIDTH, ADDR_WIDTH)
    fsm_fft_writer_io_in_t fsm_fft_writer_io_in_q[$];
    fsm_fft_writer_io_out_t fsm_fft_writer_io_out_q[$];
    // Memory samples the command BEFORE the same edge's writer register update.
    fsm_fft_writer_io_out_t committed_q[$];
    bit output_known[$];
    logic [1:0] write_kind[$]; // Model annotation: 0=hold, 1=B/Y1, 2=A/saved-Y0.
    bit idle[$];             // Metadata only; every item still advances one clock.
    logic [7:0] error_state[$];
    logic end_last_sequence = 0;
    function new();
    endfunction
endclass
