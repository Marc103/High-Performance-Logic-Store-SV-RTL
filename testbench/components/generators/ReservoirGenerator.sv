import constant_functions_pkg::*;

class ReservoirGenerator #(type T);
    `RESERVOIR_IO_IN_STRUCT(T::DATA_WIDTH)

    TriggerableQueueBroadcaster #(T) out_broadcaster;

    int seed;

    function new(TriggerableQueueBroadcaster #(T) out_broadcaster);
        this.out_broadcaster = out_broadcaster;
        this.seed = 17;
    endfunction

    task automatic add_io(
        ref T io_obj,
        input logic idle,
        input logic rst,
        input logic fill_valid,
        input logic drain_ready
    );
        reservoir_io_in_t reservoir_io_in;

        reservoir_io_in.rst_i         = rst;
        reservoir_io_in.fill_data_i   = this.seed[T::DATA_WIDTH - 1 : 0];
        reservoir_io_in.fill_valid_i  = fill_valid;
        reservoir_io_in.drain_ready_i = drain_ready;

        if(fill_valid) begin
            this.seed++;
        end

        io_obj.reservoir_io_in_q.push_back(reservoir_io_in);
        io_obj.idle.push_back(idle);
    endtask

    task automatic add_mixed_traffic(ref T io_obj);
        int occupancy;
        logic fill_valid;
        logic drain_ready;
        logic do_drain;
        logic do_fill;

        occupancy = 0;
        for(int cycle = 0; cycle < 64; cycle++) begin
            fill_valid = ((cycle % 2) == 0) || ((cycle % 7) == 0);
            drain_ready = ((cycle % 3) != 0) || ((cycle % 11) == 0);

            add_io(io_obj, 0, 0, fill_valid, drain_ready);

            do_drain = drain_ready && (occupancy > 0);
            do_fill = fill_valid && ((occupancy < T::ENTRIES) || do_drain);
            if(do_drain) occupancy--;
            if(do_fill) occupancy++;
        end
    endtask

    task automatic run();
        T io_obj;
        io_obj = new();

        // Establish a known empty state and exercise empty drain requests.
        for(int cycle = 0; cycle < 3; cycle++) begin
            add_io(io_obj, 0, 1, 0, 0);
        end
        for(int cycle = 0; cycle < 2; cycle++) begin
            add_io(io_obj, 0, 0, 0, 1);
        end

        // Fill through the watermark and consume every backpressure entry.
        for(int entry = 0; entry < T::ENTRIES; entry++) begin
            add_io(io_obj, 0, 0, 1, 0);
        end
        for(int cycle = 0; cycle < 2; cycle++) begin
            add_io(io_obj, 0, 0, 0, 0);
        end

        // Maintain full occupancy while replacing the drained item each cycle.
        for(int cycle = 0; cycle < (T::ENTRIES + 2); cycle++) begin
            add_io(io_obj, 0, 0, 1, 1);
        end

        // Create partial occupancy and exercise the partial fill/drain path.
        for(int entry = 0; entry < (T::ENTRIES / 2); entry++) begin
            add_io(io_obj, 0, 0, 0, 1);
        end
        for(int cycle = 0; cycle < (T::ENTRIES + 2); cycle++) begin
            add_io(io_obj, 0, 0, 1, 1);
        end

        // Return to full, drain to empty, and cross the burstmark boundary again.
        for(int entry = 0; entry < (T::ENTRIES / 2); entry++) begin
            add_io(io_obj, 0, 0, 1, 0);
        end
        for(int entry = 0; entry < T::ENTRIES; entry++) begin
            add_io(io_obj, 0, 0, 0, 1);
        end
        add_io(io_obj, 0, 0, 0, 1);
        for(int entry = 0; entry < T::BURSTMARK; entry++) begin
            add_io(io_obj, 0, 0, 1, 0);
        end
        add_io(io_obj, 0, 0, 0, 0);

        // Reset while occupied, then run a deterministic mixed-traffic stress phase.
        for(int cycle = 0; cycle < 2; cycle++) begin
            add_io(io_obj, 0, 1, 0, 0);
        end
        add_io(io_obj, 0, 0, 0, 0);
        add_mixed_traffic(io_obj);

        // End in a known state so the final status outputs are also checked.
        add_io(io_obj, 0, 1, 0, 0);
        add_io(io_obj, 0, 0, 0, 0);

        io_obj.end_last_sequence = 1;
        out_broadcaster.push(io_obj);
    endtask
endclass
