import constant_functions_pkg::*;

class ReservoirModel #(type T);
    `RESERVOIR_IO_IN_STRUCT(T::DATA_WIDTH)
    `RESERVOIR_IO_OUT_STRUCT(T::DATA_WIDTH)

    TriggerableQueue #(T) in_queue;
    TriggerableQueueBroadcaster #(T) out_broadcaster;

    protected logic [T::DATA_WIDTH - 1 : 0] entries[$];
    protected logic unsigned [7:0] error_state;

    function new(
        TriggerableQueue #(T) in_queue,
        TriggerableQueueBroadcaster #(T) out_broadcaster
    );
        this.in_queue = in_queue;
        this.out_broadcaster = out_broadcaster;
        this.error_state = 0;
    endfunction

    task automatic model_cycle(
        input reservoir_io_in_t reservoir_io_in,
        output reservoir_io_out_t reservoir_io_out
    );
        logic do_drain;
        logic do_fill;
        logic [T::DATA_WIDTH - 1 : 0] discarded;

        if(reservoir_io_in.rst_i) begin
            this.entries.delete();
        end else begin
            do_drain = reservoir_io_in.drain_ready_i && (this.entries.size() > 0);
            do_fill = reservoir_io_in.fill_valid_i &&
                ((this.entries.size() < T::ENTRIES) || do_drain);

            if(do_drain) begin
                discarded = this.entries.pop_front();
            end
            if(do_fill) begin
                this.entries.push_back(reservoir_io_in.fill_data_i);
            end
        end

        if(this.entries.size() > T::ENTRIES) begin
            this.error_state = 1;
        end

        reservoir_io_out.fill_ready_o =
            (this.entries.size() < T::WATERMARK_ENTRIES);
        reservoir_io_out.drain_valid_o = (this.entries.size() > 0);
        reservoir_io_out.drain_burstmark_o =
            (this.entries.size() >= T::BURSTMARK);

        if(this.entries.size() > 0) begin
            reservoir_io_out.drain_data_o = this.entries[0];
        end else begin
            reservoir_io_out.drain_data_o = '0;
        end
    endtask

    task automatic run();
        T io_obj_in;
        T io_obj_out;
        reservoir_io_in_t reservoir_io_in;
        reservoir_io_out_t reservoir_io_out;

        forever begin
            in_queue.pop(io_obj_in);
            io_obj_out = new();

            while(io_obj_in.reservoir_io_in_q.size() > 0) begin
                reservoir_io_in = io_obj_in.reservoir_io_in_q.pop_front();

                if(io_obj_in.idle.pop_front()) begin
                    continue;
                end

                model_cycle(reservoir_io_in, reservoir_io_out);
                io_obj_out.error_state.push_back(this.error_state);
                io_obj_out.reservoir_io_out_q.push_back(reservoir_io_out);
            end

            io_obj_out.end_last_sequence = io_obj_in.end_last_sequence;
            out_broadcaster.push(io_obj_out);
        end
    endtask
endclass
