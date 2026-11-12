import constant_functions_pkg::*;

class FsmFftReaderScoreboard #(type T);
    `FSM_FFT_READER_IO_IN_STRUCT(T::SAMPLES_ADDR_WIDTH)
    `FSM_FFT_READER_IO_OUT_STRUCT(T::SAMPLES_ADDR_WIDTH, T::TWIDDLES_ADDR_WIDTH)
    TriggerableQueue #(T) in_queue_dut;
    TriggerableQueue #(T) in_queue_golden;

    function new(TriggerableQueue #(T) in_queue_dut, TriggerableQueue #(T) in_queue_golden);
        this.in_queue_dut = in_queue_dut;
        this.in_queue_golden = in_queue_golden;
    endfunction

    task automatic run();
        T dut_io, model_io;
        fsm_fft_reader_io_in_t stimulus, sampled;
        fsm_fft_reader_io_out_t actual, expected;
        int sequences = 0, cycles = 0, runs = 0, requests = 0, returns = 0;
        int resets = 0, a_commands = 0, b_commands = 0, twiddles = 0, tails = 0;
        int sequence_size;
        logic [7:0] model_error;
        forever begin
            in_queue_golden.pop(model_io);
            in_queue_dut.pop(dut_io);
            sequence_size = model_io.fsm_fft_reader_io_out_q.size();
            if(dut_io.fsm_fft_reader_io_out_q.size() != sequence_size ||
               dut_io.fsm_fft_reader_io_in_q.size() != sequence_size ||
               model_io.fsm_fft_reader_io_in_q.size() != sequence_size ||
               model_io.error_state.size() != sequence_size)
                $fatal(1, "Sequence %0d queue-size mismatch", sequences);
            if(dut_io.end_last_sequence !== model_io.end_last_sequence)
                $fatal(1, "Reader final marker mismatch");
            for(int i = 0; i < sequence_size; i++) begin
                actual = dut_io.fsm_fft_reader_io_out_q.pop_front();
                expected = model_io.fsm_fft_reader_io_out_q.pop_front();
                stimulus = model_io.fsm_fft_reader_io_in_q.pop_front();
                sampled = dut_io.fsm_fft_reader_io_in_q.pop_front();
                model_error = model_io.error_state.pop_front();
                if(!(sampled === stimulus) || model_error !== 0)
                    $fatal(1, "Cycle %0d driver/model stimulus mismatch", cycles);
                if(!({actual.a_b_rd_en_o, actual.a_valid_o, actual.b_valid_o, actual.w_rd_en_o,
                      actual.w_valid_o, actual.busy_o, actual.fft_done_o} ===
                     {expected.a_b_rd_en_o, expected.a_valid_o, expected.b_valid_o, expected.w_rd_en_o,
                      expected.w_valid_o, expected.busy_o, expected.fft_done_o}))
                    $fatal(1, "Cycle %0d reader controls differ: actual=%p expected=%p stimulus=%p",
                           cycles, actual, expected, stimulus);
                // Only enabled request addresses are part of the consumer's interface contract.
                if(expected.a_b_rd_en_o && actual.a_b_rd_addr_o !== expected.a_b_rd_addr_o)
                    $fatal(1, "Cycle %0d sample address actual=%0d expected=%0d", cycles,
                           actual.a_b_rd_addr_o, expected.a_b_rd_addr_o);
                if(expected.w_rd_en_o && actual.w_rd_addr_o !== expected.w_rd_addr_o)
                    $fatal(1, "Cycle %0d twiddle address actual=%0d expected=%0d", cycles,
                           actual.w_rd_addr_o, expected.w_rd_addr_o);
                if((actual.w_rd_en_o && !actual.a_b_rd_en_o) ||
                   actual.b_valid_o !== actual.w_valid_o || (actual.a_valid_o && actual.b_valid_o))
                    $fatal(1, "Cycle %0d invalid B/W pairing or conflicting returns", cycles);
                if(actual.a_b_rd_en_o) begin
                    requests++;
                    if(actual.w_rd_en_o) b_commands++; else a_commands++;
                end
                if(actual.w_rd_en_o && actual.w_rd_addr_o != 0) twiddles++;
                if(actual.a_valid_o || actual.b_valid_o) returns++;
                if(!actual.busy_o && (actual.a_valid_o || actual.b_valid_o)) tails++;
                if(actual.fft_done_o) runs++;
                if(stimulus.rst_i) resets++;
                cycles++;
            end
            $display("Sequence %0d passed: %0d clock comparisons", sequences, sequence_size);
            sequences++;
            if(dut_io.end_last_sequence) begin
                if(runs < 2 || a_commands == 0 || b_commands == 0 || returns == 0 || resets == 0 ||
                   (T::MAX_FFT_LOG2 > 1 && twiddles == 0) ||
                   (T::READ_LATENCY > T::II_CYCLES - 2 && tails == 0))
                    $fatal(1, "Missing required reader command/return/reset/twiddle/tail coverage");
                $display("Coverage: A=%0d B/W=%0d nonzero-twiddles=%0d reset-clocks=%0d idle-return-tails=%0d",
                         a_commands, b_commands, twiddles, resets, tails);
                $display("Scoreboard completed: %0d sequences, %0d cycles, %0d runs, %0d requests, %0d returns, II=%0d R=%0d",
                         sequences, cycles, runs, requests, returns, T::II_CYCLES, T::READ_LATENCY);
                $finish;
            end
        end
    endtask
endclass
