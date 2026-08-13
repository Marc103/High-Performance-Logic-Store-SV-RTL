import constant_functions_pkg::*;

class QueuePushCouplerGenerator #(type T);
    `QUEUE_PUSH_COUPLER_IO_IN_STRUCT(T::DATA_WIDTH)

    TriggerableQueueBroadcaster #(T) out_broadcaster;
    int seed;

    function new(TriggerableQueueBroadcaster #(T) out_broadcaster);
        this.out_broadcaster = out_broadcaster;
        this.seed = 23;
    endfunction

    task automatic add_io(
        ref T io_obj,
        input logic idle,
        input logic rst,
        input logic wr_valid,
        input logic full,
        input logic lookahead,
        input logic advance_seed
    );
        queue_push_coupler_io_in_t queue_push_coupler_io_in;

        queue_push_coupler_io_in.rst_i       = rst;
        queue_push_coupler_io_in.wr_data_i   = this.seed[T::DATA_WIDTH - 1 : 0];
        queue_push_coupler_io_in.wr_valid_i  = wr_valid;
        queue_push_coupler_io_in.full_i      = full;
        queue_push_coupler_io_in.lookahead_i = lookahead;

        if(wr_valid && advance_seed) begin
            this.seed++;
        end

        io_obj.queue_push_coupler_io_in_q.push_back(queue_push_coupler_io_in);
        io_obj.idle.push_back(idle);
    endtask

    task automatic run();
        T io_obj;
        io_obj = new();

        // Establish an empty, inactive buffered state.
        for(int cycle = 0; cycle < 3; cycle++) begin
            add_io(io_obj, 0, 1, 0, 0, 0, 0);
        end
        add_io(io_obj, 0, 0, 0, 0, 0, 0);

        // Cover every valid/full/lookahead input combination. Impossible queue
        // flag combinations are still useful for proving full has final priority.
        for(int valid = 0; valid <= 1; valid++) begin
            for(int full = 0; full <= 1; full++) begin
                for(int lookahead = 0; lookahead <= 1; lookahead++) begin
                    add_io(io_obj, 0, 0, valid[0], full[0], lookahead[0],
                        valid[0] && ((T::SIMPLE == 0) || !full[0]));
                end
            end
        end

        // Isolate the strict no-backpressure tests from the combination sweep.
        for(int cycle = 0; cycle < 2; cycle++) begin
            add_io(io_obj, 0, 1, 0, 0, 0, 0);
        end

        // Fill while the downstream queue is blocked, crossing burstready and
        // reaching the no-backpressure reservoir's true full condition.
        for(int entry = 0; entry < T::RESERVOIR_ENTRIES; entry++) begin
            add_io(io_obj, 0, 0, 1, 1, 1, 1);
        end

        // Hold one transaction stable while ready is low. Releasing the queue
        // first starts the registered drain; acceptance occurs only after space
        // exists on the following cycle.
        for(int cycle = 0; cycle < 3; cycle++) begin
            add_io(io_obj, 0, 0, 1, 1, 1, 0);
        end
        add_io(io_obj, 0, 0, 1, 0, 0, 0);
        add_io(io_obj, 0, 0, 1, 0, 0, 0);
        add_io(io_obj, 0, 0, 1, 0, 0, 1);

        // Release with ample queue space and drain completely.
        for(int cycle = 0; cycle < (T::RESERVOIR_ENTRIES + 4); cycle++) begin
            add_io(io_obj, 0, 0, 0, 0, 0, 0);
        end

        // Refill, then expose exactly one queue slot. This checks the registered
        // push pulse and its one-cycle-ahead cancellation.
        for(int entry = 0; entry < 3; entry++) begin
            add_io(io_obj, 0, 0, 1, 1, 1, 1);
        end
        for(int cycle = 0; cycle < 4; cycle++) begin
            add_io(io_obj, 0, 0, (cycle == 0), 0, 1, (cycle == 0));
        end
        add_io(io_obj, 0, 0, 0, 1, 1, 0);

        // Continuous traffic exercises simultaneous reservoir fill/drain and
        // repeated transitions between plentiful space, one slot, and full.
        for(int cycle = 0; cycle < 48; cycle++) begin
            logic full;
            logic lookahead;

            full = ((cycle % 13) == 9) || ((cycle % 13) == 10);
            lookahead = full || ((cycle % 7) == 5);
            // Keep data stable throughout this stress phase. Repeated accepted
            // values are legal, while any ready-low interval also obeys the
            // ready/valid stability requirement.
            add_io(io_obj, 0, 0, ((cycle % 4) != 3), full, lookahead, 0);
        end

        // Reset while occupied and verify clean restart behavior.
        for(int cycle = 0; cycle < 2; cycle++) begin
            add_io(io_obj, 0, 1, 0, 0, 0, 0);
        end
        add_io(io_obj, 0, 0, 1, 0, 0, 1);
        for(int cycle = 0; cycle < 5; cycle++) begin
            add_io(io_obj, 0, 0, 0, 0, 0, 0);
        end

        io_obj.end_last_sequence = 1;
        out_broadcaster.push(io_obj);
    endtask
endclass
