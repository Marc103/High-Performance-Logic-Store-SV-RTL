import constant_functions_pkg::*;

// Schedule the two command deadlines and model pre-edge memory consumption.
// No RTL enum values or next-state logic are used by this reference.
class FsmFftWriterModel #(type T);
    typedef logic [T::DATA_WIDTH - 1 : 0] word_t;
    `FSM_FFT_WRITER_IO_IN_STRUCT(T::DATA_WIDTH, T::ADDR_WIDTH)
    `FSM_FFT_WRITER_IO_OUT_STRUCT(T::DATA_WIDTH, T::ADDR_WIDTH)
    TriggerableQueue #(T) in_queue;
    TriggerableQueueBroadcaster #(T) out_broadcaster;
    fsm_fft_writer_io_out_t command;
    word_t saved_y0;
    bit previous_valid = 0, known = 0;
    int cycle = 0, a_due = -1, next_accept_cycle = 0, last_accept_cycle = -1;
    int accepted = 0, completed = 0, held_valid = 0, aborted = 0, canceled = 0;
    int minimum_spacing = 0, fft_spacing = 0, gapped = 0;

    function new(TriggerableQueue #(T) in_queue, TriggerableQueueBroadcaster #(T) out_broadcaster);
        this.in_queue = in_queue;
        this.out_broadcaster = out_broadcaster;
        command = '0; // Address/data are masked until the first qualified capture.
    endfunction

    task automatic step(fsm_fft_writer_io_in_t stimulus, T result);
        fsm_fft_writer_io_out_t committed;
        logic [1:0] kind;
        if($isunknown({stimulus.rst_i, stimulus.valid_i})) $fatal(1, "Unknown writer control inputs");
        // At this edge memory sees the previous command, masked by the current raw reset.
        committed = command;
        committed.wr_en_o = command.wr_en_o && !stimulus.rst_i;
        if(stimulus.rst_i && command.wr_en_o) canceled++;
        command.wr_en_o = 0;
        kind = 0;
        if(stimulus.rst_i) begin
            if(a_due >= cycle) aborted++;
            a_due = -1;
            next_accept_cycle = cycle + 1;
            previous_valid = 0;
            last_accept_cycle = -1;
        end else begin
            if(cycle == a_due) begin
                if($isunknown(stimulus.a_wr_addr_i)) $fatal(1, "Unknown A on required sampling clock %0d", cycle);
                command.wr_addr_o = stimulus.a_wr_addr_i;
                command.wr_data_o = saved_y0;
                command.wr_en_o = 1;
                kind = 2;
                a_due = -1;
                completed++;
            end
            if(stimulus.valid_i && previous_valid) held_valid++;
            if(stimulus.valid_i && !previous_valid && cycle >= next_accept_cycle) begin
                if($isunknown({stimulus.b_wr_addr_i, stimulus.y0_i, stimulus.y1_i}))
                    $fatal(1, "Unknown B/result data on accepted clock %0d", cycle);
                if(kind != 0) $fatal(1, "Model scheduled conflicting command deadlines");
                if(last_accept_cycle >= 0) begin
                    if(cycle - last_accept_cycle == 2) minimum_spacing++;
                    if(cycle - last_accept_cycle == 4) fft_spacing++;
                    if(cycle - last_accept_cycle > 4) gapped++;
                end
                last_accept_cycle = cycle;
                command.wr_addr_o = stimulus.b_wr_addr_i;
                command.wr_data_o = stimulus.y1_i;
                command.wr_en_o = 1;
                saved_y0 = stimulus.y0_i;
                known = 1;
                kind = 1;
                a_due = cycle + 1;
                next_accept_cycle = cycle + 2;
                accepted++;
            end
            previous_valid = stimulus.valid_i;
        end
        result.fsm_fft_writer_io_in_q.push_back(stimulus);
        result.fsm_fft_writer_io_out_q.push_back(command);
        result.committed_q.push_back(committed);
        result.output_known.push_back(known);
        result.write_kind.push_back(kind);
        result.error_state.push_back(0);
        cycle++;
    endtask

    task automatic run();
        T source, result;
        fsm_fft_writer_io_in_t stimulus;
        forever begin
            in_queue.pop(source);
            result = new();
            if(source.idle.size() != source.fsm_fft_writer_io_in_q.size()) $fatal(1, "Model input metadata mismatch");
            while(source.fsm_fft_writer_io_in_q.size() > 0) begin
                stimulus = source.fsm_fft_writer_io_in_q.pop_front();
                void'(source.idle.pop_front());
                step(stimulus, result); // Include every idle clock, especially the A/commit clocks.
            end
            result.end_last_sequence = source.end_last_sequence;
            if(source.end_last_sequence) begin
                if(a_due >= cycle || command.wr_en_o || previous_valid)
                    $fatal(1, "Stimulus ended before all writer commands drained");
                if(accepted == 0 || completed == 0 || held_valid == 0 || aborted == 0 || canceled == 0 ||
                   minimum_spacing == 0 || fft_spacing == 0 || gapped == 0)
                    $fatal(1, "Missing writer protocol coverage");
                $display("Model coverage: accepted=%0d completed=%0d held-valid=%0d aborted=%0d canceled=%0d II2=%0d II4=%0d gaps=%0d",
                         accepted, completed, held_valid, aborted, canceled, minimum_spacing, fft_spacing, gapped);
            end
            out_broadcaster.push(result);
        end
    endtask
endclass
