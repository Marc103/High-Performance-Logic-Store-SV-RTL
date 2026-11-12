import constant_functions_pkg::*;

// Mathematical radix-2 traversal and absolute deadlines, independent of RTL state encoding.
class FsmFftReaderModel #(type T);
    `FSM_FFT_READER_IO_IN_STRUCT(T::SAMPLES_ADDR_WIDTH)
    `FSM_FFT_READER_IO_OUT_STRUCT(T::SAMPLES_ADDR_WIDTH, T::TWIDDLES_ADDR_WIDTH)
    typedef struct packed {
        int due_cycle;
        bit is_a;
        bit is_return;
        logic [T::SAMPLES_ADDR_WIDTH - 1 : 0] sample_addr;
        logic [T::TWIDDLES_ADDR_WIDTH - 1 : 0] twiddle_addr;
    } event_t;
    TriggerableQueue #(T) in_queue;
    TriggerableQueueBroadcaster #(T) out_broadcaster;
    fsm_fft_reader_io_in_t registered_inputs;
    event_t pending[$];
    int cycle = 0, finish_cycle = -1;
    int launch_n, launch_m;
    bit running = 0;
    int accepted_count = 0, completed_count = 0, busy_go_count = 0, abort_count = 0;

    function new(TriggerableQueue #(T) in_queue, TriggerableQueueBroadcaster #(T) out_broadcaster);
        this.in_queue = in_queue;
        this.out_broadcaster = out_broadcaster;
        registered_inputs = '0;
        registered_inputs.rst_i = 1;
        registered_inputs.fft_point_size_i = 2;
        registered_inputs.fft_whole_iterations_i = 1;
    endfunction

    function automatic void schedule(int due_cycle, bit is_a, bit is_return, int addr, int k);
        event_t item;
        item.due_cycle = due_cycle;
        item.is_a = is_a;
        item.is_return = is_return;
        item.sample_addr = T::SAMPLES_ADDR_WIDTH'(addr);
        item.twiddle_addr = T::TWIDDLES_ADDR_WIDTH'(k);
        pending.push_back(item);
    endfunction

    function automatic void launch();
        int index, a, b, k, due;
        launch_n = int'(registered_inputs.fft_point_size_i);
        launch_m = int'(registered_inputs.fft_whole_iterations_i);
        if($isunknown({registered_inputs.fft_point_size_i, registered_inputs.fft_whole_iterations_i}) ||
           launch_n < 2 || (launch_n & (launch_n - 1)) != 0 || launch_n > T::MAX_FFT_SIZE ||
           launch_m < 1 || launch_m * launch_n > T::DATA_DEPTH)
            $fatal(1, "Invalid accepted reader configuration N=%0d M=%0d", launch_n, launch_m);
        index = 0;
        for(int size = 2; size <= launch_n; size *= 2)
            for(int whole = 0; whole < launch_m; whole++)
                for(int base_addr = 0; base_addr < launch_n; base_addr += size)
                    for(int pair_index = 0; pair_index < size / 2; pair_index++) begin
                        a = whole * launch_n + base_addr + pair_index;
                        b = a + size / 2;
                        k = pair_index * (launch_n / size);
                        due = cycle + 1 + index * T::II_CYCLES;
                        schedule(due, 0, 0, b, k);
                        schedule(due + 1, 1, 0, a, 0);
                        schedule(due + T::READ_LATENCY, 0, 1, b, k);
                        schedule(due + T::READ_LATENCY + 1, 1, 1, a, 0);
                        index++;
                    end
        finish_cycle = cycle + index * T::II_CYCLES;
        running = 1;
        accepted_count++;
    endfunction

    task automatic step(fsm_fft_reader_io_in_t stimulus, T output_sequence);
        fsm_fft_reader_io_out_t expected;
        event_t item;
        expected = '0;
        if($isunknown({stimulus.rst_i, stimulus.go_i})) $fatal(1, "Unknown reader controls");
        // New registered reset masks ports now; previous registered reset clears controls/valids.
        if(stimulus.rst_i || registered_inputs.rst_i) begin
            if(running || pending.size() != 0) abort_count++;
            pending.delete();
            running = 0;
            finish_cycle = -1;
        end else begin
            if(!running && registered_inputs.go_i) launch();
            else if(running && registered_inputs.go_i) busy_go_count++;
            if(running && (int'(stimulus.fft_point_size_i) != launch_n ||
                           int'(stimulus.fft_whole_iterations_i) != launch_m))
                $fatal(1, "Configuration changed during a reader run");
            for(int i = pending.size() - 1; i >= 0; i--) begin
                if(pending[i].due_cycle < cycle) $fatal(1, "Missed reader model deadline");
                if(pending[i].due_cycle == cycle) begin
                    item = pending[i];
                    pending.delete(i);
                    if(item.is_return) begin
                        if(item.is_a) expected.a_valid_o = 1;
                        else begin expected.b_valid_o = 1; expected.w_valid_o = 1; end
                    end else begin
                        if(expected.a_b_rd_en_o) $fatal(1, "Duplicate sample request deadline");
                        expected.a_b_rd_en_o = 1;
                        expected.a_b_rd_addr_o = item.sample_addr;
                        if(!item.is_a) begin
                            expected.w_rd_en_o = 1;
                            expected.w_rd_addr_o = item.twiddle_addr;
                        end
                    end
                end
            end
            if(running && cycle == finish_cycle) begin
                expected.fft_done_o = 1;
                completed_count++;
                running = 0;
            end
            expected.busy_o = running;
        end
        registered_inputs = stimulus;
        output_sequence.fsm_fft_reader_io_in_q.push_back(stimulus);
        output_sequence.fsm_fft_reader_io_out_q.push_back(expected);
        output_sequence.error_state.push_back(0);
        cycle++;
    endtask

    task automatic run();
        T source, result;
        fsm_fft_reader_io_in_t stimulus;
        bit idle_clock;
        forever begin
            in_queue.pop(source);
            result = new();
            while(source.fsm_fft_reader_io_in_q.size() > 0) begin
                stimulus = source.fsm_fft_reader_io_in_q.pop_front();
                idle_clock = source.idle.pop_front();
                // Idle metadata never suppresses clocks: returns and registered controls still advance.
                step(stimulus, result);
            end
            result.end_last_sequence = source.end_last_sequence;
            if(source.end_last_sequence) begin
                if(running || pending.size() != 0 || registered_inputs.go_i)
                    $fatal(1, "Stimulus ended before reader/control-return drain");
                if(accepted_count < 2 || completed_count < 2 || busy_go_count == 0 || abort_count == 0)
                    $fatal(1, "Missing launch/completion/busy-go/reset-abort coverage");
                $display("Model coverage: accepted=%0d completed=%0d busy-go-clocks=%0d aborts=%0d",
                         accepted_count, completed_count, busy_go_count, abort_count);
            end
            out_broadcaster.push(result);
        end
    endtask
endclass
