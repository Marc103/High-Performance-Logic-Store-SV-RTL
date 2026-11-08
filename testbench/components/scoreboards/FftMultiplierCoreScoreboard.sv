import constant_functions_pkg::*;

class FftMultiplierCoreScoreboard #(type T);
    typedef logic [T::DATA_WIDTH - 1 : 0] word_t;
    `FFT_MULTIPLIER_CORE_IO_IN_STRUCT(T::DATA_WIDTH)
    `FFT_MULTIPLIER_CORE_IO_OUT_STRUCT(T::DATA_WIDTH)
    TriggerableQueue #(T) in_queue_dut;
    TriggerableQueue #(T) in_queue_golden;

    function new(TriggerableQueue #(T) in_queue_dut, TriggerableQueue #(T) in_queue_golden);
        this.in_queue_dut = in_queue_dut;
        this.in_queue_golden = in_queue_golden;
    endfunction

    function automatic word_t output_word(fft_multiplier_core_io_out_t value, int index);
        case(index)
            0: return value.wrbr_o;
            1: return value.wibi_o;
            2: return value.wrbi_o;
            3: return value.wibr_o;
            4: return value.ar_o;
            5: return value.ai_o;
            default: begin $fatal(1, "Invalid scoreboard output index"); return '0; end
        endcase
    endfunction

    task automatic run();
        T dut_io, model_io;
        fft_multiplier_core_io_in_t stimulus, sampled_stimulus;
        fft_multiplier_core_io_out_t actual, expected, previous;
        logic [5:0] known, writes;
        logic [7:0] model_error;
        word_t value;
        bit have_previous = 0;
        int sequences = 0, cycles = 0, strobes = 0, products = 0, resets = 0;
        int zero_products = 0, special_products = 0, finite_products = 0;
        int sequence_size;
        forever begin
            in_queue_golden.pop(model_io);
            in_queue_dut.pop(dut_io);
            sequence_size = model_io.fft_multiplier_core_io_out_q.size();
            if(dut_io.fft_multiplier_core_io_out_q.size() != sequence_size ||
               dut_io.fft_multiplier_core_io_in_q.size() != sequence_size ||
               model_io.fft_multiplier_core_io_in_q.size() != sequence_size ||
               model_io.error_state.size() != sequence_size || model_io.known_mask.size() != sequence_size ||
               model_io.write_mask.size() != sequence_size)
                $fatal(1, "Sequence %0d queue-size mismatch", sequences);
            if(dut_io.end_last_sequence !== model_io.end_last_sequence)
                $fatal(1, "Sequence %0d final-marker mismatch", sequences);
            for(int item = 0; item < sequence_size; item++) begin
                actual = dut_io.fft_multiplier_core_io_out_q.pop_front();
                expected = model_io.fft_multiplier_core_io_out_q.pop_front();
                sampled_stimulus = dut_io.fft_multiplier_core_io_in_q.pop_front();
                stimulus = model_io.fft_multiplier_core_io_in_q.pop_front();
                model_error = model_io.error_state.pop_front();
                known = model_io.known_mask.pop_front();
                writes = model_io.write_mask.pop_front();
                if(model_error !== 0 || !(sampled_stimulus === stimulus))
                    $fatal(1, "Sequence %0d item %0d driver/model stimulus mismatch or model error", sequences, item);
                if(actual.valid_o !== expected.valid_o)
                    $fatal(1, "Cycle %0d sequence %0d item %0d valid_o=%b expected=%b rst=%b WBvalid=%b",
                           cycles, sequences, item, actual.valid_o, expected.valid_o, stimulus.rst_i, stimulus.w_b_valid_i);
                for(int index = 0; index < 6; index++) begin
                    value = output_word(actual, index);
                    // Compare all known data bits, including signed-zero sign and reserved payload bits.
                    if(known[index] && !(value === output_word(expected, index)))
                        $fatal(1, "Cycle %0d output %0d DUT=%h model=%h writes=%b rst=%b WBvalid=%b LATENCY=%0d",
                               cycles, index, value, output_word(expected, index), writes,
                               stimulus.rst_i, stimulus.w_b_valid_i, T::LATENCY);
                    // Unknown startup values are allowed, but even Xs must hold without a valid write.
                    if(have_previous && !writes[index] && !(value === output_word(previous, index)))
                        $fatal(1, "Cycle %0d output %0d changed without a qualified write (rst=%b)", cycles, index, stimulus.rst_i);
                    if(index < 4 && writes[index]) begin
                        products++;
                        if(value[T::MANTISSA_WIDTH + T::EXPONENT_WIDTH - 1 : T::MANTISSA_WIDTH] == '0) begin
                            if(value[T::MANTISSA_WIDTH - 1 : 0] != '0)
                                $fatal(1, "Noncanonical zero product at cycle %0d", cycles);
                            zero_products++;
                        end else if((&value[T::MANTISSA_WIDTH + T::EXPONENT_WIDTH - 1 : T::MANTISSA_WIDTH]) && value[T::MANTISSA_WIDTH - 1])
                            special_products++;
                        else finite_products++;
                    end
                end
                if(actual.valid_o) begin
                    if((known & 6'h33) !== 6'h33) $fatal(1, "Early strobe before WrBr/WiBi/A were written");
                    if(writes !== 6'h32) $fatal(1, "valid_o must coincide with WiBi and both A writes");
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
                if(zero_products == 0 || special_products == 0 || resets == 0)
                    $fatal(1, "Missing required zero/special/reset coverage");
                $display("Coverage: %0d reset clocks, %0d zero, %0d special, %0d finite product writes",
                         resets, zero_products, special_products, finite_products);
                $display("Scoreboard completed: %0d sequences, %0d cycles, %0d strobes, %0d products, LATENCY=%0d",
                         sequences, cycles, strobes, products, T::LATENCY);
                $finish;
            end
        end
    endtask
endclass
