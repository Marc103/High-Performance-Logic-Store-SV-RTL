import constant_functions_pkg::*;

class FftAdderCoreModel #(type T);
    typedef T::adder_io_t adder_io_t;
    typedef logic [T::DATA_WIDTH - 1 : 0] word_t;
    `FFT_ADDER_CORE_IO_IN_STRUCT(T::DATA_WIDTH)
    `FFT_ADDER_CORE_IO_OUT_STRUCT(T::DATA_WIDTH)
    `ALTERNATE_BASE_FP_ADDER_IO_IN_STRUCT(T::DATA_WIDTH)
    typedef struct packed {
        int due_cycle;
        int destination;
        word_t value;
    } scheduled_write_t;
    TriggerableQueue #(T) in_queue;
    TriggerableQueueBroadcaster #(T) out_broadcaster;
    AlternateBaseFpAdderModel #(adder_io_t) arithmetic;
    scheduled_write_t pending[$];
    fft_adder_core_io_out_t held_outputs;
    logic [3:0] initialized = '0;
    bit previous_valid = 0;
    int next_accept_cycle = 0;
    int sample_ti_cycle = -1;
    word_t saved_ai;
    int cycle = 0;
    int accepted_count = 0, ignored_count = 0, reset_count = 0, cancelled_count = 0;

    function new(TriggerableQueue #(T) in_queue, TriggerableQueueBroadcaster #(T) out_broadcaster);
        this.in_queue = in_queue;
        this.out_broadcaster = out_broadcaster;
        arithmetic = new(null, null);
        held_outputs = '0; // Data comparison is masked until the first qualified write.
    endfunction

    function automatic word_t negate(word_t value);
        value[T::DATA_WIDTH - 1] = ~value[T::DATA_WIDTH - 1];
        return value;
    endfunction

    function automatic word_t add(word_t a, word_t b);
        alternate_base_fp_adder_io_in_t transaction;
        transaction = {a, b};
        if($isunknown(transaction) ||
           (!arithmetic.finite_operand(a) && !arithmetic.special_operand(a)) ||
           (!arithmetic.finite_operand(b) && !arithmetic.special_operand(b)))
            $fatal(1, "Noncanonical/unknown accepted operand at cycle %0d: a=%h b=%h", cycle, a, b);
        // Preserve the existing RNE, flush-to-zero, and combined NaN/Inf policy.
        return arithmetic.add_values(transaction);
    endfunction

    function automatic void schedule(int due_cycle, int destination, word_t value);
        scheduled_write_t item;
        item = {due_cycle, destination, value};
        pending.push_back(item);
    endfunction

    task automatic step(fft_adder_core_io_in_t stimulus, T output_sequence);
        logic [3:0] writes;
        word_t tr, ti;
        scheduled_write_t item;
        writes = '0;
        held_outputs.valid_o = 0;
        if($isunknown({stimulus.rst_i, stimulus.valid_i})) $fatal(1, "Unknown control at cycle %0d", cycle);
        if(stimulus.rst_i) begin
            if(pending.size() != 0 || sample_ti_cycle >= cycle) cancelled_count++;
            pending.delete();
            sample_ti_cycle = -1;
            previous_valid = 0;
            next_accept_cycle = cycle + 1;
            reset_count++;
            // Datapath data and initialized bits survive reset.
        end else begin
            if(cycle == sample_ti_cycle) begin
                ti = add(stimulus.wrbi_i, stimulus.wibr_i);
                schedule(cycle + 2*T::ADDER_LATENCY + 1, 1, add(ti, saved_ai));
                schedule(cycle + 2*T::ADDER_LATENCY + 2, 3, add(negate(ti), saved_ai));
                sample_ti_cycle = -1;
            end
            if(stimulus.valid_i && !previous_valid) begin
                if(cycle >= next_accept_cycle) begin
                    accepted_count++;
                    next_accept_cycle = cycle + 4;
                    tr = add(stimulus.wrbr_i, negate(stimulus.wibi_i));
                    saved_ai = stimulus.ai_i;
                    if($isunknown(saved_ai)) $fatal(1, "Unknown Ai at accepted cycle %0d", cycle);
                    schedule(cycle + 2*T::ADDER_LATENCY + 1, 0, add(tr, stimulus.ar_i));
                    schedule(cycle + 2*T::ADDER_LATENCY + 2, 2, add(negate(tr), stimulus.ar_i));
                    sample_ti_cycle = cycle + 2;
                end else ignored_count++;
            end
            previous_valid = stimulus.valid_i;
            // Absolute deadlines are independent of the DUT's FSM encoding and tokens.
            for(int i = pending.size()-1; i >= 0; i--) begin
                if(pending[i].due_cycle < cycle) $fatal(1, "Missed model deadline");
                if(pending[i].due_cycle == cycle) begin
                    item = pending[i];
                    pending.delete(i);
                    if(writes[item.destination]) $fatal(1, "Duplicate destination at cycle %0d", cycle);
                    writes[item.destination] = 1;
                    initialized[item.destination] = 1;
                    case(item.destination)
                        0: held_outputs.y0r_o = item.value;
                        1: held_outputs.y0i_o = item.value;
                        2: held_outputs.y1r_o = item.value;
                        3: begin held_outputs.y1i_o = item.value; held_outputs.valid_o = 1; end
                        default: $fatal(1, "Invalid model destination");
                    endcase
                end
            end
        end
        output_sequence.fft_adder_core_io_in_q.push_back(stimulus);
        output_sequence.fft_adder_core_io_out_q.push_back(held_outputs);
        output_sequence.error_state.push_back(0);
        output_sequence.known_mask.push_back(initialized);
        output_sequence.write_mask.push_back(writes);
        cycle++;
    endtask

    task automatic run();
        T input_sequence, output_sequence;
        fft_adder_core_io_in_t stimulus;
        bit idle_item;
        forever begin
            in_queue.pop(input_sequence);
            if(input_sequence.idle.size() != input_sequence.fft_adder_core_io_in_q.size())
                $fatal(1, "Model input/idle queue mismatch");
            output_sequence = new();
            output_sequence.end_last_sequence = input_sequence.end_last_sequence;
            while(input_sequence.fft_adder_core_io_in_q.size() > 0) begin
                stimulus = input_sequence.fft_adder_core_io_in_q.pop_front();
                idle_item = input_sequence.idle.pop_front();
                step(stimulus, output_sequence);
            end
            if(input_sequence.end_last_sequence) begin
                if(pending.size() != 0 || sample_ti_cycle >= cycle) $fatal(1, "Final sequence did not drain");
                if(accepted_count == 0 || ignored_count == 0 || cancelled_count == 0)
                    $fatal(1, "Missing accepted/busy/reset-cancel coverage");
                $display("Model coverage: %0d accepted, %0d ignored busy strobes, %0d reset clocks, %0d cancellations",
                         accepted_count, ignored_count, reset_count, cancelled_count);
            end
            out_broadcaster.push(output_sequence);
        end
    endtask
endclass
