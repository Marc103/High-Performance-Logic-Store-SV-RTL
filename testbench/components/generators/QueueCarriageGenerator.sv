import constant_functions_pkg::*;

class QueueCarriageGenerator #(type T);
    `QUEUE_CARRIAGE_IO_IN_STRUCT(T::DATA_WIDTH)

    TriggerableQueueBroadcaster #(T) out_broadcaster;
    protected int seed;

    function new(TriggerableQueueBroadcaster #(T) out_broadcaster);
        this.out_broadcaster = out_broadcaster;
        this.seed = 19;
    endfunction

    task automatic add_cycle(
        ref T io_obj,
        input logic wr_rst,
        input logic rd_rst,
        input logic wr_valid,
        input logic rd_ready,
        input logic idle
    );
        queue_carriage_io_in_t queue_carriage_io_in;

        queue_carriage_io_in.wr_rst_i = wr_rst;
        queue_carriage_io_in.rd_rst_i = rd_rst;
        queue_carriage_io_in.wr_data_i = this.seed[T::DATA_WIDTH - 1 : 0];
        queue_carriage_io_in.wr_valid_i = wr_valid;
        queue_carriage_io_in.rd_ready_i = rd_ready;

        if(wr_valid) this.seed++;

        io_obj.queue_carriage_io_in_q.push_back(queue_carriage_io_in);
        io_obj.idle.push_back(idle);
    endtask

    task automatic run();
        T io_obj;
        int stall_items;
        io_obj = new();

        // queue_async registers reset release internally, so hold reset and then idle.
        for(int cycle = 0; cycle < 6; cycle++) begin
            add_cycle(io_obj, 1, 1, 0, 0, 0);
        end
        for(int cycle = 0; cycle < 8; cycle++) begin
            add_cycle(io_obj, 0, 0, 0, 0, 0);
        end

        // Continuous simultaneous ingress and egress.
        for(int item = 0; item < 32; item++) begin
            add_cycle(io_obj, 0, 0, 1, 1, 0);
        end

        for(int cycle = 0; cycle < 6; cycle++) begin
            add_cycle(io_obj, 0, 0, 0, 1, 0);
        end

        // Accumulate a bounded amount while downstream is stalled.
        stall_items = (T::DATA_DEPTH >= 8) ? (T::DATA_DEPTH / 2) : 2;
        for(int item = 0; item < stall_items; item++) begin
            add_cycle(io_obj, 0, 0, 1, 0, 0);
        end
        for(int cycle = 0; cycle < 12; cycle++) begin
            add_cycle(io_obj, 0, 0, 0, 0, 0);
        end

        // Mixed traffic exercises repeated stall and restart behavior.
        for(int cycle = 0; cycle < 40; cycle++) begin
            add_cycle(
                io_obj,
                0,
                0,
                ((cycle % 3) != 1),
                ((cycle % 7) != 2) && ((cycle % 7) != 3),
                0
            );
        end

        // Drain every queue and reservoir pipeline before ending the sequence.
        for(int cycle = 0; cycle < 192; cycle++) begin
            add_cycle(io_obj, 0, 0, 0, 1, 0);
        end

        add_cycle(io_obj, 0, 0, 0, 1, 0);
        io_obj.end_last_sequence = 1;
        this.out_broadcaster.push(io_obj);
    endtask
endclass
