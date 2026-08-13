import constant_functions_pkg::*;

class QueuePushCouplerModel #(type T);
    `QUEUE_PUSH_COUPLER_IO_IN_STRUCT(T::DATA_WIDTH)
    `QUEUE_PUSH_COUPLER_IO_OUT_STRUCT(T::DATA_WIDTH, T::ADDR_WIDTH)

    TriggerableQueue #(T) in_queue;
    TriggerableQueueBroadcaster #(T) out_broadcaster;

    protected logic [T::DATA_WIDTH - 1 : 0] reservoir_entries[$];
    protected logic queue_push = 0;
    protected logic unsigned [7:0] error_state = 0;

    function new(
        TriggerableQueue #(T) in_queue,
        TriggerableQueueBroadcaster #(T) out_broadcaster
    );
        this.in_queue = in_queue;
        this.out_broadcaster = out_broadcaster;
    endfunction

    task automatic model_simple(
        input queue_push_coupler_io_in_t queue_push_coupler_io_in,
        output queue_push_coupler_io_out_t queue_push_coupler_io_out
    );
        queue_push_coupler_io_out.ready_o = !queue_push_coupler_io_in.full_i;
        if(T::ASYNC == 1) begin
            if(T::BURST_SIZE == 1) begin
                queue_push_coupler_io_out.burstready_o =
                    !queue_push_coupler_io_in.full_i;
            end else begin
                queue_push_coupler_io_out.burstready_o = 0;
            end
        end else begin
            queue_push_coupler_io_out.burstready_o =
                !queue_push_coupler_io_in.lookahead_i;
        end

        queue_push_coupler_io_out.wr_data_o = queue_push_coupler_io_in.wr_data_i;
        queue_push_coupler_io_out.push_o =
            queue_push_coupler_io_in.wr_valid_i &&
            !queue_push_coupler_io_in.full_i;
        queue_push_coupler_io_out.more_than_or_eq_o =
            T::DATA_DEPTH - T::BURST_SIZE + 1;
    endtask

    task automatic model_buffered(
        input queue_push_coupler_io_in_t queue_push_coupler_io_in,
        output queue_push_coupler_io_out_t queue_push_coupler_io_out
    );
        logic queue_push_next;
        logic reservoir_at_least_two_left;
        logic reservoir_one_left;
        logic do_drain;
        logic do_fill;
        logic [T::DATA_WIDTH - 1 : 0] discarded;

        reservoir_at_least_two_left = (this.reservoir_entries.size() >= 2);
        reservoir_one_left = (this.reservoir_entries.size() == 1);

        queue_push_next = 0;
        if(!queue_push_coupler_io_in.full_i) begin
            if(!queue_push_coupler_io_in.lookahead_i) begin
                if(reservoir_at_least_two_left) begin
                    queue_push_next = 1;
                end else if(reservoir_one_left && !this.queue_push) begin
                    queue_push_next = 1;
                end
            end else if((reservoir_at_least_two_left || reservoir_one_left) &&
                        !this.queue_push) begin
                queue_push_next = 1;
            end
        end

        if(queue_push_coupler_io_in.rst_i) begin
            queue_push_next = 0;
            this.reservoir_entries.delete();
        end else begin
            do_drain = this.queue_push && (this.reservoir_entries.size() > 0);
            do_fill = queue_push_coupler_io_in.wr_valid_i &&
                (this.reservoir_entries.size() < T::RESERVOIR_ENTRIES);

            if(do_drain) begin
                discarded = this.reservoir_entries.pop_front();
            end
            if(do_fill) begin
                this.reservoir_entries.push_back(queue_push_coupler_io_in.wr_data_i);
            end
        end

        this.queue_push = queue_push_next;

        if(this.reservoir_entries.size() > T::RESERVOIR_ENTRIES) begin
            this.error_state = 1;
        end
        if(this.queue_push && (this.reservoir_entries.size() == 0)) begin
            this.error_state = 2;
        end

        queue_push_coupler_io_out.ready_o =
            (this.reservoir_entries.size() < T::RESERVOIR_ENTRIES);
        queue_push_coupler_io_out.burstready_o =
            ((T::RESERVOIR_ENTRIES - this.reservoir_entries.size()) >=
                T::BURST_SIZE);
        queue_push_coupler_io_out.push_o = this.queue_push;
        queue_push_coupler_io_out.more_than_or_eq_o = T::DATA_DEPTH - 1;

        if(this.reservoir_entries.size() > 0) begin
            queue_push_coupler_io_out.wr_data_o = this.reservoir_entries[0];
        end else begin
            queue_push_coupler_io_out.wr_data_o = '0;
        end
    endtask

    task automatic run();
        T io_obj_in;
        T io_obj_out;
        queue_push_coupler_io_in_t queue_push_coupler_io_in;
        queue_push_coupler_io_out_t queue_push_coupler_io_out;

        forever begin
            in_queue.pop(io_obj_in);
            io_obj_out = new();

            while(io_obj_in.queue_push_coupler_io_in_q.size() > 0) begin
                queue_push_coupler_io_in =
                    io_obj_in.queue_push_coupler_io_in_q.pop_front();

                if(io_obj_in.idle.pop_front()) begin
                    continue;
                end

                if(T::SIMPLE == 1) begin
                    model_simple(queue_push_coupler_io_in, queue_push_coupler_io_out);
                end else begin
                    model_buffered(queue_push_coupler_io_in, queue_push_coupler_io_out);
                end

                io_obj_out.error_state.push_back(this.error_state);
                io_obj_out.queue_push_coupler_io_out_q.push_back(queue_push_coupler_io_out);
            end

            io_obj_out.end_last_sequence = io_obj_in.end_last_sequence;
            out_broadcaster.push(io_obj_out);
        end
    endtask
endclass
