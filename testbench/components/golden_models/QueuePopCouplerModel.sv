import constant_functions_pkg::*;

class QueuePopCouplerModel #(type T);
    `QUEUE_POP_COUPLER_IO_IN_STRUCT(T::DATA_WIDTH)
    `QUEUE_POP_COUPLER_IO_OUT_STRUCT(T::DATA_WIDTH, T::ADDR_WIDTH)

    TriggerableQueue #(T) in_queue;
    TriggerableQueueBroadcaster #(T) out_broadcaster;

    protected logic [T::DATA_WIDTH - 1 : 0] reservoir_entries[$];
    protected logic queue_pop = 0;
    protected logic unsigned [7:0] error_state = 0;

    function new(
        TriggerableQueue #(T) in_queue,
        TriggerableQueueBroadcaster #(T) out_broadcaster
    );
        this.in_queue = in_queue;
        this.out_broadcaster = out_broadcaster;
    endfunction

    task automatic model_cycle(
        input queue_pop_coupler_io_in_t queue_pop_coupler_io_in,
        output queue_pop_coupler_io_out_t queue_pop_coupler_io_out
    );
        logic fill_ready;
        logic queue_pop_next;
        logic do_drain;
        logic do_fill;

        fill_ready = (this.reservoir_entries.size() < T::RESERVOIR_WATERMARK_ENTRIES);
        queue_pop_next = 0;

        if(!queue_pop_coupler_io_in.rst_i && !queue_pop_coupler_io_in.empty_i) begin
            if(!queue_pop_coupler_io_in.lookahead_i) begin
                queue_pop_next = fill_ready;
            end else if(fill_ready && !this.queue_pop) begin
                queue_pop_next = 1;
            end
        end

        if(queue_pop_coupler_io_in.rst_i) begin
            this.reservoir_entries.delete();
        end else begin
            do_drain = queue_pop_coupler_io_in.ready_i &&
                (this.reservoir_entries.size() > 0);
            do_fill = queue_pop_coupler_io_in.rd_valid_i &&
                ((this.reservoir_entries.size() < T::RESERVOIR_ENTRIES) || do_drain);

            if(do_drain) begin
                void'(this.reservoir_entries.pop_front());
            end
            if(do_fill) begin
                this.reservoir_entries.push_back(queue_pop_coupler_io_in.rd_data_i);
            end
            if(queue_pop_coupler_io_in.rd_valid_i && !do_fill) begin
                this.error_state = 1;
            end
        end

        this.queue_pop = queue_pop_next;

        queue_pop_coupler_io_out.pop_o = this.queue_pop;
        queue_pop_coupler_io_out.less_than_or_eq_o = 'd1;
        queue_pop_coupler_io_out.rd_valid_o = (this.reservoir_entries.size() > 0);
        queue_pop_coupler_io_out.burstvalid_o =
            (this.reservoir_entries.size() >= T::BURSTMARK);

        if(this.reservoir_entries.size() > 0) begin
            queue_pop_coupler_io_out.rd_data_o = this.reservoir_entries[0];
        end else begin
            queue_pop_coupler_io_out.rd_data_o = '0;
        end
    endtask

    task automatic run();
        T io_obj_in;
        T io_obj_out;
        queue_pop_coupler_io_in_t queue_pop_coupler_io_in;
        queue_pop_coupler_io_out_t queue_pop_coupler_io_out;

        forever begin
            this.in_queue.pop(io_obj_in);
            io_obj_out = new();

            while(io_obj_in.queue_pop_coupler_io_in_q.size() > 0) begin
                queue_pop_coupler_io_in =
                    io_obj_in.queue_pop_coupler_io_in_q.pop_front();

                if(io_obj_in.idle.pop_front()) begin
                    continue;
                end

                model_cycle(queue_pop_coupler_io_in, queue_pop_coupler_io_out);
                io_obj_out.error_state.push_back(this.error_state);
                io_obj_out.queue_pop_coupler_io_out_q.push_back(queue_pop_coupler_io_out);
            end

            io_obj_out.end_last_sequence = io_obj_in.end_last_sequence;
            this.out_broadcaster.push(io_obj_out);
        end
    endtask
endclass
