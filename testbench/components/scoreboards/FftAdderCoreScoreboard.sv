import constant_functions_pkg::*;

class FftAdderCoreScoreboard #(type T);
    typedef logic [T::DATA_WIDTH - 1 : 0] word_t;
    `FFT_ADDER_CORE_IO_IN_STRUCT(T::DATA_WIDTH)
    `FFT_ADDER_CORE_IO_OUT_STRUCT(T::DATA_WIDTH)
    TriggerableQueue #(T) in_queue_dut;
    TriggerableQueue #(T) in_queue_golden;

    function new(TriggerableQueue #(T) in_queue_dut, TriggerableQueue #(T) in_queue_golden);
        this.in_queue_dut = in_queue_dut;
        this.in_queue_golden = in_queue_golden;
    endfunction

    function automatic word_t output_word(fft_adder_core_io_out_t value, int index);
        case(index)
            0: return value.y0r_o;
            1: return value.y0i_o;
            2: return value.y1r_o;
            3: return value.y1i_o;
            default: begin $fatal(1, "Invalid scoreboard output index"); return '0; end
        endcase
    endfunction

    task automatic run();
        T dut_io, model_io;
        fft_adder_core_io_in_t stimulus, sampled_stimulus;
        fft_adder_core_io_out_t actual, expected, previous;
        logic [3:0] known, writes;
        logic [7:0] model_error;
        word_t value, expected_value, comparable_value;
        bit have_previous = 0;
        int sequences = 0, cycles = 0, strobes = 0, results = 0, resets = 0;
        int zero_results = 0, special_results = 0, finite_results = 0;
        int sequence_size;
        forever begin
            in_queue_golden.pop(model_io);
            in_queue_dut.pop(dut_io);
            sequence_size = model_io.fft_adder_core_io_out_q.size();
            if(dut_io.fft_adder_core_io_out_q.size() != sequence_size ||
               dut_io.fft_adder_core_io_in_q.size() != sequence_size ||
               model_io.fft_adder_core_io_in_q.size() != sequence_size ||
               model_io.error_state.size() != sequence_size || model_io.known_mask.size() != sequence_size ||
               model_io.write_mask.size() != sequence_size)
                $fatal(1, "Sequence %0d queue-size mismatch", sequences);
            if(dut_io.end_last_sequence !== model_io.end_last_sequence)
                $fatal(1, "Sequence %0d final-marker mismatch", sequences);
            for(int item = 0; item < sequence_size; item++) begin
                actual = dut_io.fft_adder_core_io_out_q.pop_front();
                expected = model_io.fft_adder_core_io_out_q.pop_front();
                sampled_stimulus = dut_io.fft_adder_core_io_in_q.pop_front();
                stimulus = model_io.fft_adder_core_io_in_q.pop_front();
                model_error = model_io.error_state.pop_front();
                known = model_io.known_mask.pop_front();
                writes = model_io.write_mask.pop_front();
                if(model_error !== 0 || !(sampled_stimulus === stimulus))
                    $fatal(1, "Sequence %0d item %0d driver/model stimulus mismatch or model error", sequences, item);
                if(actual.valid_o !== expected.valid_o)
                    $fatal(1, "Cycle %0d sequence %0d item %0d valid_o=%b expected=%b rst=%b valid_i=%b",
                           cycles, sequences, item, actual.valid_o, expected.valid_o, stimulus.rst_i, stimulus.valid_i);
                for(int index = 0; index < 4; index++) begin
                    value = output_word(actual, index);
                    // Existing adder scoreboard policy: compare every bit except the
                    // sign of canonical zero. Do not mask malformed zeros or Xs.
                    expected_value = output_word(expected, index);
                    comparable_value = value;
                    if(value[T::DATA_WIDTH - 2 : 0] === '0) comparable_value[T::DATA_WIDTH - 1] = 0;
                    if(expected_value[T::DATA_WIDTH - 2 : 0] === '0) expected_value[T::DATA_WIDTH - 1] = 0;
                    if(known[index] && !(comparable_value === expected_value))
                        $fatal(1, "Cycle %0d output %0d DUT=%h model=%h writes=%b rst=%b valid_i=%b LATENCY=%0d",
                               cycles, index, value, output_word(expected, index), writes,
                               stimulus.rst_i, stimulus.valid_i, T::LATENCY);
                    // Unknown startup values are allowed, but even Xs must hold without a valid write.
                    if(have_previous && !writes[index] && !(value === output_word(previous, index)))
                        $fatal(1, "Cycle %0d output %0d changed without a qualified write (rst=%b)", cycles, index, stimulus.rst_i);
                    if(writes[index]) begin
                        results++;
                        if(value[T::MANTISSA_WIDTH + T::EXPONENT_WIDTH - 1 : T::MANTISSA_WIDTH] == '0) begin
                            if(value[T::MANTISSA_WIDTH - 1 : 0] != '0)
                                $fatal(1, "Noncanonical zero result at cycle %0d", cycles);
                            zero_results++;
                        end else if((&value[T::MANTISSA_WIDTH + T::EXPONENT_WIDTH - 1 : T::MANTISSA_WIDTH]) && value[T::MANTISSA_WIDTH - 1])
                            special_results++;
                        else finite_results++;
                    end
                end
                if(actual.valid_o) begin
                    if(known !== 4'hf) $fatal(1, "Completion strobe before all four outputs were written");
                    if(writes !== 4'h8) $fatal(1, "valid_o must coincide with the final Y1i write");
                    strobes++;
                end
                if(stimulus.rst_i) resets++;
                previous = actual;
                have_previous = 1;
                cycles++;
            end
            $display("Sequence %0d passed: %0d clock comparisons", sequences, sequence_size);
            sequences++;
            if(dut_io.end_last_sequence) begin
                if(zero_results == 0 || special_results == 0 || resets == 0)
                    $fatal(1, "Missing required zero/special/reset coverage");
                $display("Coverage: %0d reset clocks, %0d zero, %0d special, %0d finite result writes",
                         resets, zero_results, special_results, finite_results);
                $display("Scoreboard completed: %0d sequences, %0d cycles, %0d strobes, %0d results, LATENCY=%0d",
                         sequences, cycles, strobes, results, T::LATENCY);
                $finish;
            end
        end
    endtask
endclass
