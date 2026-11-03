import constant_functions_pkg::*;

class AlternateBaseFpAdderScoreboard #(type T);
    `ALTERNATE_BASE_FP_ADDER_IO_IN_STRUCT(T::DATA_WIDTH)
    `ALTERNATE_BASE_FP_ADDER_IO_OUT_STRUCT(T::DATA_WIDTH)
    TriggerableQueue #(T) in_queue_dut;
    TriggerableQueue #(T) in_queue_golden;

    function new(TriggerableQueue #(T) in_queue_dut, TriggerableQueue #(T) in_queue_golden);
        this.in_queue_dut = in_queue_dut;
        this.in_queue_golden = in_queue_golden;
    endfunction

    task automatic run();
        T dut_io, model_io;
        alternate_base_fp_adder_io_in_t stimulus;
        alternate_base_fp_adder_io_out_t actual, expected, actual_value, expected_value;
        logic [7:0] model_error;
        int sequences = 0;
        int comparisons = 0;
        int sequence_size;
        forever begin
            in_queue_golden.pop(model_io);
            in_queue_dut.pop(dut_io);
            sequence_size = model_io.alternate_base_fp_adder_io_out_q.size();
            if(dut_io.alternate_base_fp_adder_io_out_q.size() != sequence_size ||
               model_io.error_state.size() != sequence_size ||
               model_io.alternate_base_fp_adder_io_in_q.size() != sequence_size)
                $fatal(1, "Sequence %0d queue-size mismatch: DUT=%0d model=%0d", sequences,
                       dut_io.alternate_base_fp_adder_io_out_q.size(), sequence_size);
            if(dut_io.end_last_sequence !== model_io.end_last_sequence)
                $fatal(1, "Sequence %0d final marker mismatch", sequences);
            for(int i = 0; i < sequence_size; i++) begin
                actual = dut_io.alternate_base_fp_adder_io_out_q.pop_front();
                expected = model_io.alternate_base_fp_adder_io_out_q.pop_front();
                stimulus = model_io.alternate_base_fp_adder_io_in_q.pop_front();
                model_error = model_io.error_state.pop_front();
                if(model_error !== 0) $fatal(1, "Model error %0d at sequence %0d item %0d", model_error, sequences, i);
                actual_value = actual;
                expected_value = expected;
                // All finite zero encodings are numerically equivalent. Preserve Xs.
                if(actual.sum_o[T::MANTISSA_WIDTH - 1 : 0] === '0) actual_value.sum_o = '0;
                if(expected.sum_o[T::MANTISSA_WIDTH - 1 : 0] === '0) expected_value.sum_o = '0;
                if(!(actual_value === expected_value))
                    $fatal(1, "Sequence %0d item %0d a=%h b=%h DUT=%h model=%h LATENCY=%0d",
                           sequences, i, stimulus.a_i, stimulus.b_i, actual.sum_o, expected.sum_o, T::LATENCY);
                comparisons++;
            end
            $display("Sequence %0d passed: %0d comparisons", sequences, sequence_size);
            sequences++;
            if(dut_io.end_last_sequence) begin
                $display("Scoreboard completed: %0d sequences, %0d comparisons, LATENCY=%0d", sequences, comparisons, T::LATENCY);
                $finish;
            end
        end
    endtask
endclass
