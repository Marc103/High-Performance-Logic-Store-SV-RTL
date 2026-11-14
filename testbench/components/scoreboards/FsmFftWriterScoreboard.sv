import constant_functions_pkg::*;

class FsmFftWriterScoreboard #(type T);
    `FSM_FFT_WRITER_IO_IN_STRUCT(T::DATA_WIDTH, T::ADDR_WIDTH)
    `FSM_FFT_WRITER_IO_OUT_STRUCT(T::DATA_WIDTH, T::ADDR_WIDTH)
    TriggerableQueue #(T) in_queue_dut;
    TriggerableQueue #(T) in_queue_golden;

    function new(TriggerableQueue #(T) in_queue_dut, TriggerableQueue #(T) in_queue_golden);
        this.in_queue_dut = in_queue_dut;
        this.in_queue_golden = in_queue_golden;
    endfunction

    task automatic run();
        T actual_seq, expected_seq;
        fsm_fft_writer_io_in_t stimulus, sampled;
        fsm_fft_writer_io_out_t actual, expected, consumed, expected_consumed;
        bit known;
        logic [1:0] kind;
        logic [7:0] model_error;
        int size, sequences = 0, clocks = 0, a_writes = 0, b_writes = 0, commits = 0;
        int resets = 0, preserved_y0 = 0, reset_suppression = 0;
        forever begin
            in_queue_golden.pop(expected_seq);
            in_queue_dut.pop(actual_seq);
            size = expected_seq.fsm_fft_writer_io_out_q.size();
            if(actual_seq.fsm_fft_writer_io_out_q.size() != size ||
               actual_seq.fsm_fft_writer_io_in_q.size() != size || actual_seq.committed_q.size() != size ||
               expected_seq.fsm_fft_writer_io_in_q.size() != size || expected_seq.committed_q.size() != size ||
               expected_seq.output_known.size() != size || expected_seq.write_kind.size() != size ||
               expected_seq.error_state.size() != size)
                $fatal(1, "Writer sequence %0d queue-size mismatch", sequences);
            if(actual_seq.end_last_sequence !== expected_seq.end_last_sequence)
                $fatal(1, "Writer sequence marker mismatch");
            for(int i = 0; i < size; i++) begin
                stimulus = expected_seq.fsm_fft_writer_io_in_q.pop_front();
                sampled = actual_seq.fsm_fft_writer_io_in_q.pop_front();
                actual = actual_seq.fsm_fft_writer_io_out_q.pop_front();
                expected = expected_seq.fsm_fft_writer_io_out_q.pop_front();
                consumed = actual_seq.committed_q.pop_front();
                expected_consumed = expected_seq.committed_q.pop_front();
                known = expected_seq.output_known.pop_front();
                kind = expected_seq.write_kind.pop_front();
                model_error = expected_seq.error_state.pop_front();
                if(!(sampled === stimulus) || model_error !== 0)
                    $fatal(1, "Clock %0d writer driver/model stimulus mismatch", clocks);
                if(actual.wr_en_o !== expected.wr_en_o ||
                   (known && ({actual.wr_addr_o, actual.wr_data_o} !== {expected.wr_addr_o, expected.wr_data_o})))
                    $fatal(1, "Clock %0d writer command mismatch actual=%p expected=%p input=%p kind=%0d known=%b",
                           clocks, actual, expected, stimulus, kind, known);
                if(consumed.wr_en_o !== expected_consumed.wr_en_o ||
                   (expected_consumed.wr_en_o && consumed !== expected_consumed))
                    $fatal(1, "Clock %0d memory commit mismatch actual=%p expected=%p reset=%b",
                           clocks, consumed, expected_consumed, stimulus.rst_i);
                if(kind == 1) b_writes++;
                if(kind == 2) begin
                    a_writes++;
                    if(stimulus.y0_i !== expected.wr_data_o) preserved_y0++;
                end
                if(consumed.wr_en_o) commits++;
                if(stimulus.rst_i) begin
                    resets++;
                    if(actual.wr_en_o !== 0 || consumed.wr_en_o !== 0)
                        $fatal(1, "Write escaped reset suppression");
                    reset_suppression++;
                end
                clocks++;
            end
            $display("Sequence %0d passed: %0d command/commit clock comparisons", sequences, size);
            sequences++;
            if(actual_seq.end_last_sequence) begin
                if(a_writes == 0 || b_writes == 0 || commits == 0 || resets == 0 || preserved_y0 == 0 ||
                   a_writes + b_writes <= commits || reset_suppression == 0)
                    $fatal(1, "Missing writer data/commit/reset coverage");
                $display("Coverage: B/Y1=%0d A/Y0=%0d saved-Y0=%0d reset-clocks=%0d canceled-commands=%0d",
                         b_writes, a_writes, preserved_y0, resets, a_writes + b_writes - commits);
                $display("Scoreboard completed: %0d sequences, %0d cycles, %0d B writes, %0d A writes, %0d commits, DATA_WIDTH=%0d ADDR_WIDTH=%0d",
                         sequences, clocks, b_writes, a_writes, commits, T::DATA_WIDTH, T::ADDR_WIDTH);
                $finish;
            end
        end
    endtask
endclass
