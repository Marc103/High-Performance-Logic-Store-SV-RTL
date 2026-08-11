import constant_functions_pkg::*;

class QueuePopCouplerGenerator #(type T);
    `QUEUE_POP_COUPLER_IO_IN_STRUCT(T::DATA_WIDTH)

    TriggerableQueueBroadcaster #(T) out_broadcaster;

    protected logic [T::DATA_WIDTH - 1 : 0] source_entries[$];
    protected int pending_delay[$];
    protected logic [T::DATA_WIDTH - 1 : 0] pending_data[$];
    protected int reservoir_occupancy;
    protected logic queue_pop_state;
    protected int seed;

    function new(TriggerableQueueBroadcaster #(T) out_broadcaster);
        this.out_broadcaster = out_broadcaster;
        this.seed = 23;
        this.reservoir_occupancy = 0;
        this.queue_pop_state = 0;
    endfunction

    function automatic void refill(int count);
        for(int entry = 0; entry < count; entry++) begin
            this.source_entries.push_back(this.seed[T::DATA_WIDTH - 1 : 0]);
            this.seed++;
        end
    endfunction

    function automatic void reset_reference();
        this.source_entries.delete();
        this.pending_delay.delete();
        this.pending_data.delete();
        this.reservoir_occupancy = 0;
        this.queue_pop_state = 0;
    endfunction

    task automatic add_cycle(
        ref T io_obj,
        input logic rst,
        input logic ready
    );
        queue_pop_coupler_io_in_t queue_pop_coupler_io_in;
        logic source_empty;
        logic source_lookahead;
        logic accepted_pop;
        logic due_valid;
        logic [T::DATA_WIDTH - 1 : 0] accepted_data;
        logic [T::DATA_WIDTH - 1 : 0] due_data;
        logic fill_ready;
        logic queue_pop_next;
        logic do_drain;
        logic do_fill;

        if(rst) begin
            this.reset_reference();
        end

        source_empty = (this.source_entries.size() == 0);
        source_lookahead = (T::ASYNC == 1)
            ? (this.source_entries.size() == 1)
            : (this.source_entries.size() <= 1);

        accepted_pop = (!rst) && this.queue_pop_state && !source_empty;
        if(accepted_pop) begin
            accepted_data = this.source_entries.pop_front();
            this.pending_delay.push_back(T::QUEUE_READ_LATENCY - 1);
            this.pending_data.push_back(accepted_data);
        end

        due_valid = (!rst) && (this.pending_delay.size() > 0) &&
            (this.pending_delay[0] == 0);
        due_data = '0;
        if(due_valid) begin
            void'(this.pending_delay.pop_front());
            due_data = this.pending_data.pop_front();
        end

        for(int item = 0; item < this.pending_delay.size(); item++) begin
            if(this.pending_delay[item] > 0) begin
                this.pending_delay[item]--;
            end
        end

        fill_ready = (this.reservoir_occupancy < T::RESERVOIR_WATERMARK_ENTRIES);
        queue_pop_next = 0;
        if(!rst && !source_empty) begin
            if(!source_lookahead) begin
                queue_pop_next = fill_ready;
            end else if(fill_ready && !this.queue_pop_state) begin
                queue_pop_next = 1;
            end
        end

        queue_pop_coupler_io_in.rst_i       = rst;
        queue_pop_coupler_io_in.empty_i     = source_empty;
        queue_pop_coupler_io_in.lookahead_i = source_lookahead;
        queue_pop_coupler_io_in.rd_data_i   = due_data;
        queue_pop_coupler_io_in.rd_valid_i  = due_valid;
        queue_pop_coupler_io_in.ready_i     = ready;

        if(rst) begin
            this.reservoir_occupancy = 0;
        end else begin
            do_drain = ready && (this.reservoir_occupancy > 0);
            do_fill = due_valid &&
                ((this.reservoir_occupancy < T::RESERVOIR_ENTRIES) || do_drain);

            if(due_valid && !do_fill) begin
                $fatal(1, "QueuePopCoupler generated more in-flight data than the reservoir can hold");
            end
            if(do_drain) this.reservoir_occupancy--;
            if(do_fill) this.reservoir_occupancy++;
        end

        this.queue_pop_state = queue_pop_next;
        io_obj.queue_pop_coupler_io_in_q.push_back(queue_pop_coupler_io_in);
        io_obj.idle.push_back(0);
    endtask

    task automatic drain_all(ref T io_obj);
        for(int cycle = 0;
            (cycle < 256) &&
            ((this.source_entries.size() > 0) ||
             (this.pending_delay.size() > 0) ||
             (this.reservoir_occupancy > 0) ||
             this.queue_pop_state);
            cycle++) begin
            add_cycle(io_obj, 0, 1);
        end
    endtask

    task automatic run();
        T io_obj;
        io_obj = new();

        for(int cycle = 0; cycle < 3; cycle++) begin
            add_cycle(io_obj, 1, 0);
        end

        // Continuous traffic establishes and maintains a burst.
        refill(T::RESERVOIR_ENTRIES + 24);
        for(int cycle = 0; cycle < (T::SPOOL_UP + T::BURSTMARK + 10); cycle++) begin
            add_cycle(io_obj, 0, 1);
        end

        // Downstream backpressure fills through the watermark while queue data
        // already in flight consumes the backpressure entries.
        for(int cycle = 0; cycle < (T::SPOOL_UP + T::SPOOL_DOWN + 8); cycle++) begin
            add_cycle(io_obj, 0, 0);
        end

        for(int cycle = 0; cycle < 48; cycle++) begin
            add_cycle(io_obj, 0, ((cycle % 7) != 2) && ((cycle % 7) != 3));
        end
        drain_all(io_obj);

        // Reacquire after empty and exercise a short source ending at lookahead.
        refill(T::BURSTMARK + 3);
        drain_all(io_obj);

        // Reset with reads in flight, then prove a clean restart.
        refill(T::RESERVOIR_ENTRIES + 8);
        for(int cycle = 0; cycle < (T::SPOOL_UP + 2); cycle++) begin
            add_cycle(io_obj, 0, 0);
        end
        for(int cycle = 0; cycle < 2; cycle++) begin
            add_cycle(io_obj, 1, 0);
        end

        refill(T::BURSTMARK + 9);
        for(int cycle = 0; cycle < 12; cycle++) begin
            add_cycle(io_obj, 0, (cycle % 4) != 0);
        end
        drain_all(io_obj);

        io_obj.end_last_sequence = 1;
        this.out_broadcaster.push(io_obj);
    endtask
endclass
