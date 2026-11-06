import constant_functions_pkg::*;

class FftMultiplierCoreModel #(type T);
    typedef T::multiplier_io_t multiplier_io_t;
    typedef logic [T::DATA_WIDTH - 1 : 0] word_t;
    `FFT_MULTIPLIER_CORE_IO_IN_STRUCT(T::DATA_WIDTH)
    `FFT_MULTIPLIER_CORE_IO_OUT_STRUCT(T::DATA_WIDTH)
    `ALTERNATE_BASE_FP_MULTIPLIER_IO_IN_STRUCT(T::DATA_WIDTH)
    typedef struct packed {
        int due_cycle;
        int destination;
        word_t value;
    } scheduled_write_t;

    TriggerableQueue #(T) in_queue;
    TriggerableQueueBroadcaster #(T) out_broadcaster;
    AlternateBaseFpMultiplierModel #(multiplier_io_t) arithmetic;
    scheduled_write_t pending[$];
    fft_multiplier_core_io_out_t held_outputs;
    logic [5:0] initialized = '0;
    bit previous_valid = 0;
    int next_accept_cycle = 0;
    int sample_a_cycle = -1;
    int cycle = 0;
    int accepted_count = 0;
    int ignored_count = 0;
    int reset_count = 0;
    int special_zero_count = 0;

    function new(TriggerableQueue #(T) in_queue, TriggerableQueueBroadcaster #(T) out_broadcaster);
        this.in_queue = in_queue;
        this.out_broadcaster = out_broadcaster;
        arithmetic = new(null, null);
        held_outputs = '0; // Mask data until its first write; no power-up value is assumed.
    endfunction

    function automatic word_t multiply(word_t a, word_t b);
        alternate_base_fp_multiplier_io_in_t transaction;
        transaction.a_i = a;
        transaction.b_i = b;
        if($isunknown(transaction) || !arithmetic.valid_operand(a) || !arithmetic.valid_operand(b))
            $fatal(1, "Noncanonical/unknown accepted operand at model cycle %0d: a=%h b=%h", cycle, a, b);
        if((arithmetic.special_operand(a) && b[T::DATA_WIDTH - 2 : 0] == '0) ||
           (arithmetic.special_operand(b) && a[T::DATA_WIDTH - 2 : 0] == '0)) special_zero_count++;
        // This is the existing ABFP model, including RNE, signed zeros, and special-over-zero priority.
        return arithmetic.multiply_values(transaction);
    endfunction

    function automatic void schedule(int due_cycle, int destination, word_t value);
        scheduled_write_t item;
        item.due_cycle = due_cycle;
        item.destination = destination;
        item.value = value;
        pending.push_back(item);
    endfunction

    task automatic step(fft_multiplier_core_io_in_t stimulus, T output_sequence);
        logic [5:0] writes;
        scheduled_write_t item;
        writes = '0;
        held_outputs.valid_o = 0;
        if($isunknown({stimulus.rst_i, stimulus.w_b_valid_i}))
            $fatal(1, "Unknown control input at cycle %0d", cycle);
        if(stimulus.rst_i) begin
            // Control-only reset: keep data and initialized bits, cancel all scheduled writes.
            pending.delete();
            previous_valid = 0;
            next_accept_cycle = cycle + 1;
            sample_a_cycle = -1;
            reset_count++;
        end else begin
            if(cycle == sample_a_cycle) begin
                if($isunknown({stimulus.ar_i, stimulus.ai_i}))
                    $fatal(1, "Unknown A at its required sample clock %0d", cycle);
                schedule(cycle + T::MULTIPLIER_LATENCY + 1, 4, stimulus.ar_i);
                schedule(cycle + T::MULTIPLIER_LATENCY + 1, 5, stimulus.ai_i);
                sample_a_cycle = -1;
            end
            if(stimulus.w_b_valid_i && !previous_valid) begin
                if(cycle >= next_accept_cycle) begin
                    accepted_count++;
                    next_accept_cycle = cycle + 4;
                    sample_a_cycle = cycle + 1;
                    schedule(cycle + T::MULTIPLIER_LATENCY + 1, 0, multiply(stimulus.wr_i, stimulus.br_i));
                    schedule(cycle + T::MULTIPLIER_LATENCY + 2, 1, multiply(stimulus.wi_i, stimulus.bi_i));
                    schedule(cycle + T::MULTIPLIER_LATENCY + 3, 2, multiply(stimulus.wr_i, stimulus.bi_i));
                    schedule(cycle + T::MULTIPLIER_LATENCY + 4, 3, multiply(stimulus.wi_i, stimulus.br_i));
                end else ignored_count++;
            end
            previous_valid = stimulus.w_b_valid_i;
            // Absolute deadlines model the interface schedule independently of the RTL state encoding.
            for(int i = pending.size() - 1; i >= 0; i--) begin
                if(pending[i].due_cycle < cycle) $fatal(1, "Missed model deadline");
                if(pending[i].due_cycle == cycle) begin
                    item = pending[i];
                    pending.delete(i);
                    if(writes[item.destination]) $fatal(1, "Duplicate destination at cycle %0d", cycle);
                    writes[item.destination] = 1;
                    initialized[item.destination] = 1;
                    case(item.destination)
                        0: held_outputs.wrbr_o = item.value;
                        1: held_outputs.wibi_o = item.value;
                        2: held_outputs.wrbi_o = item.value;
                        3: begin held_outputs.wibr_o = item.value; held_outputs.valid_o = 1; end
                        4: held_outputs.ar_o = item.value;
                        5: held_outputs.ai_o = item.value;
                        default: $fatal(1, "Invalid model destination");
                    endcase
                end
            end
        end
        if(held_outputs.valid_o && initialized != 6'h3f) $fatal(1, "Incomplete valid model bundle");
        output_sequence.fft_multiplier_core_io_in_q.push_back(stimulus);
        output_sequence.fft_multiplier_core_io_out_q.push_back(held_outputs);
        output_sequence.error_state.push_back(0);
        output_sequence.known_mask.push_back(initialized);
        output_sequence.write_mask.push_back(writes);
        cycle++;
    endtask

    task automatic run();
        T input_sequence, output_sequence;
        fft_multiplier_core_io_in_t stimulus;
        bit idle_item;
        forever begin
            in_queue.pop(input_sequence);
            if(input_sequence.idle.size() != input_sequence.fft_multiplier_core_io_in_q.size())
                $fatal(1, "Model input/idle queue mismatch");
            output_sequence = new();
            output_sequence.end_last_sequence = input_sequence.end_last_sequence;
            while(input_sequence.fft_multiplier_core_io_in_q.size() > 0) begin
                stimulus = input_sequence.fft_multiplier_core_io_in_q.pop_front();
                idle_item = input_sequence.idle.pop_front();
                // Idle clocks still sample A, return products, and advance valid/reset timing.
                step(stimulus, output_sequence);
            end
            if(input_sequence.end_last_sequence) begin
                if(pending.size() != 0 || sample_a_cycle >= cycle) $fatal(1, "Final sequence did not drain the pipeline");
                $display("Model coverage: %0d accepted, %0d ignored busy strobes, %0d reset clocks, %0d special*zero products",
                         accepted_count, ignored_count, reset_count, special_zero_count);
            end
            out_broadcaster.push(output_sequence);
        end
    endtask
endclass
