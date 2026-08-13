import constant_functions_pkg::*;

class ReservoirNoBackpressureGenerator #(type T);
    `RESERVOIR_NO_BACKPRESSURE_IO_IN_STRUCT(T::DATA_WIDTH)

    TriggerableQueueBroadcaster #(T) out_broadcaster;

    int seed;

    function new(TriggerableQueueBroadcaster #(T) out_broadcaster);
        this.out_broadcaster = out_broadcaster;
        this.seed = 29;
    endfunction

    task automatic add_io(
        ref T io_obj,
        input logic idle,
        input logic rst,
        input logic fill_valid,
        input logic drain_ready,
        input logic advance_seed
    );
        reservoir_no_backpressure_io_in_t reservoir_no_backpressure_io_in;

        reservoir_no_backpressure_io_in.rst_i         = rst;
        reservoir_no_backpressure_io_in.fill_data_i   = this.seed[T::DATA_WIDTH - 1 : 0];
        reservoir_no_backpressure_io_in.fill_valid_i  = fill_valid;
        reservoir_no_backpressure_io_in.drain_ready_i = drain_ready;

        if(fill_valid && advance_seed) begin
            this.seed++;
        end

        io_obj.reservoir_no_backpressure_io_in_q.push_back(reservoir_no_backpressure_io_in);
        io_obj.idle.push_back(idle);
    endtask;

    task automatic run();
        T io_obj;
        io_obj = new();

        // Establish a known empty state and request drains while empty.
        for(int cycle = 0; cycle < 3; cycle++) begin
            add_io(io_obj, 0, 1, 0, 0, 0);
        end
        for(int cycle = 0; cycle < 2; cycle++) begin
            add_io(io_obj, 0, 0, 0, 1, 0);
        end

        // Fill every entry, crossing the drain burstmark and fill burstready thresholds.
        for(int entry = 0; entry < T::ENTRIES; entry++) begin
            add_io(io_obj, 0, 0, 1, 0, 1);
        end
        add_io(io_obj, 0, 0, 0, 0, 0);

        // Hold one transaction stable while full. A full-state drain rejects it on
        // that edge; it is accepted on the following edge once ready has asserted.
        for(int cycle = 0; cycle < 3; cycle++) begin
            add_io(io_obj, 0, 0, 1, 0, 0);
        end
        add_io(io_obj, 0, 0, 1, 1, 0);
        add_io(io_obj, 0, 0, 1, 0, 1);

        // Reach partial occupancy, then sustain simultaneous accepted fills and drains.
        for(int entry = 0; entry < (T::ENTRIES / 2); entry++) begin
            add_io(io_obj, 0, 0, 0, 1, 0);
        end
        for(int cycle = 0; cycle < (T::ENTRIES + 2); cycle++) begin
            add_io(io_obj, 0, 0, 1, 1, 1);
        end

        // Drain completely, refill through BURSTMARK, and cross both thresholds again.
        for(int entry = 0; entry < (T::ENTRIES + 2); entry++) begin
            add_io(io_obj, 0, 0, 0, 1, 0);
        end
        for(int entry = 0; entry < T::BURSTMARK; entry++) begin
            add_io(io_obj, 0, 0, 1, 0, 1);
        end
        add_io(io_obj, 0, 0, 0, 0, 0);

        // Reset while occupied and verify the final empty status.
        for(int cycle = 0; cycle < 2; cycle++) begin
            add_io(io_obj, 0, 1, 0, 0, 0);
        end
        add_io(io_obj, 0, 0, 0, 0, 0);

        // finished sequence.
        io_obj.end_last_sequence = 1;

        // broadcast
        out_broadcaster.push(io_obj);

    endtask
endclass
