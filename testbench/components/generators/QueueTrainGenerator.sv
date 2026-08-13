import constant_functions_pkg::*;

class QueueTrainGenerator #(type T);
    `QUEUE_TRAIN_IO_IN_STRUCT(T::DATA_WIDTH)

    TriggerableQueueBroadcaster #(T) out_broadcaster;
    protected int seed;

    function new(TriggerableQueueBroadcaster #(T) out_broadcaster);
        this.out_broadcaster = out_broadcaster;
        this.seed = 41;
    endfunction

    task automatic add_cycle(
        ref T io_obj,
        input logic wr_rst,
        input logic rd_rst,
        input logic wr_valid,
        input logic rd_ready,
        input logic idle
    );
        queue_train_io_in_t queue_train_io_in;

        queue_train_io_in.wr_rst_i = wr_rst;
        queue_train_io_in.rd_rst_i = rd_rst;
        queue_train_io_in.wr_data_i = this.seed[T::DATA_WIDTH - 1 : 0];
        queue_train_io_in.wr_valid_i = wr_valid;
        queue_train_io_in.rd_ready_i = rd_ready;

        if(wr_valid) this.seed++;

        io_obj.queue_train_io_in_q.push_back(queue_train_io_in);
        io_obj.idle.push_back(idle);
    endtask

    task automatic run();
        T io_obj;
        int stall_items;
        int drain_cycles;
        io_obj = new();

        // Hold both domains in reset, then allow resetless pipelines to settle.
        for(int cycle = 0; cycle < 8; cycle++) begin
            add_cycle(io_obj, 1, 1, 0, 0, 0);
        end
        for(int cycle = 0; cycle < 10; cycle++) begin
            add_cycle(io_obj, 0, 0, 0, 0, 0);
        end

        // Continuous ingress and egress exercises steady-state carriage handoff.
        for(int item = 0; item < 48; item++) begin
            add_cycle(io_obj, 0, 0, 1, 1, 0);
        end

        for(int cycle = 0; cycle < 8; cycle++) begin
            add_cycle(io_obj, 0, 0, 0, 1, 0);
        end

        // Fill across several carriages without reaching complete-train capacity.
        stall_items = (T::TOTAL_DATA_DEPTH >= 8) ? (T::TOTAL_DATA_DEPTH / 2) : 2;
        for(int item = 0; item < stall_items; item++) begin
            add_cycle(io_obj, 0, 0, 1, 0, 0);
        end
        for(int cycle = 0; cycle < 16; cycle++) begin
            add_cycle(io_obj, 0, 0, 0, 0, 0);
        end

        // Repeated output stalls verify restart behavior and stable stalled data.
        for(int cycle = 0; cycle < 64; cycle++) begin
            add_cycle(
                io_obj,
                0,
                0,
                ((cycle % 4) != 1),
                ((cycle % 9) != 3) && ((cycle % 9) != 4),
                0
            );
        end

        // Drain every carriage, coupler reservoir, and CDC pipeline before completion.
        drain_cycles = 128 + (T::NUMBER_OF_CARRIAGES * T::DATA_DEPTH * 8);
        for(int cycle = 0; cycle < drain_cycles; cycle++) begin
            add_cycle(io_obj, 0, 0, 0, 1, 0);
        end

        add_cycle(io_obj, 0, 0, 0, 1, 0);
        io_obj.end_last_sequence = 1;
        this.out_broadcaster.push(io_obj);
    endtask
endclass
