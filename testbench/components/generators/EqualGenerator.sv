import constant_functions_pkg::*;

class EqualGenerator #(type T);
    `EQUAL_IO_IN_STRUCT(T::DATA_WIDTH)

    TriggerableQueueBroadcaster #(T) out_broadcaster;

    int seed;

    function new(TriggerableQueueBroadcaster #(T) out_broadcaster);
        this.out_broadcaster = out_broadcaster;
        seed = 53;
    endfunction

    task automatic add_io(
        ref T io_obj,
        input logic idle,
        input logic [T::DATA_WIDTH - 1 : 0] data_a,
        input logic [T::DATA_WIDTH - 1 : 0] data_b
    );
        equal_io_in_t equal_io_in;

        equal_io_in.data_a_i = data_a;
        equal_io_in.data_b_i = data_b;

        io_obj.equal_io_in_q.push_back(equal_io_in);
        io_obj.idle.push_back(idle);
    endtask

    task automatic add_seeded_io(ref T io_obj);
        logic [T::DATA_WIDTH - 1 : 0] data_a;
        logic [T::DATA_WIDTH - 1 : 0] data_b;

        data_a = this.seed[T::DATA_WIDTH - 1 : 0];
        this.seed++;
        data_b = this.seed[T::DATA_WIDTH - 1 : 0];
        this.seed++;

        add_io(io_obj, 0, data_a, data_b);
    endtask

    task automatic run();
        T io_obj;
        io_obj = new();

        // deterministic directed tests
        add_io(io_obj, 0, '0, '0);
        add_io(io_obj, 0, '0, '1);
        add_io(io_obj, 0, '1, '0);
        add_io(io_obj, 0, 'h1, 'h1);
        add_io(io_obj, 0, 'h1, 'h2);
        add_io(io_obj, 0, 'h2, 'h1);
        add_io(io_obj, 0, 'h5, 'h5);
        add_io(io_obj, 0, {1'b1, {(T::DATA_WIDTH - 1){1'b0}}}, {1'b1, {(T::DATA_WIDTH - 1){1'b0}}});
        add_io(io_obj, 0, {1'b1, {(T::DATA_WIDTH - 1){1'b1}}}, {1'b0, {(T::DATA_WIDTH - 1){1'b1}}});

        // idle gap to verify sequence tracking
        add_io(io_obj, 1, '0, '0);

        for(int i = 0; i < 12; i++) begin
            add_seeded_io(io_obj);
        end

        // finished sequence.
        io_obj.end_last_sequence = 1;

        // broadcast
        out_broadcaster.push(io_obj);
    endtask
endclass
