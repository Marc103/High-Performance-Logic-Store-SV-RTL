import constant_functions_pkg::*;

class ReductionTreeGenerator #(type T);
    `REDUCTION_TREE_IO_IN_STRUCT(T::DATA_WIDTH)

    TriggerableQueueBroadcaster #(T) out_broadcaster;

    int seed;

    function new(TriggerableQueueBroadcaster #(T) out_broadcaster);
        this.out_broadcaster = out_broadcaster;
        seed = 71;
    endfunction

    task automatic add_io(
        ref T io_obj,
        input logic idle,
        input logic [T::DATA_WIDTH - 1 : 0] data
    );
        reduction_tree_io_in_t reduction_tree_io_in;

        reduction_tree_io_in.data_i = data;

        io_obj.reduction_tree_io_in_q.push_back(reduction_tree_io_in);
        io_obj.idle.push_back(idle);
    endtask

    task automatic add_seeded_io(ref T io_obj);
        logic [T::DATA_WIDTH - 1 : 0] data;

        for(int i = 0; i < T::DATA_WIDTH; i++) begin
            data[i] = this.seed[(i % 8)] ^ (i[0]);
        end

        this.seed++;
        add_io(io_obj, 0, data);
    endtask

    task automatic run();
        T io_obj;
        io_obj = new();

        // deterministic directed tests
        add_io(io_obj, 0, '0);
        add_io(io_obj, 0, '1);
        add_io(io_obj, 0, 'h1);
        add_io(io_obj, 0, 'h80);
        add_io(io_obj, 0, 'h5);
        add_io(io_obj, 0, 'hA);

        // idle gap to verify sequence tracking
        add_io(io_obj, 1, '0);

        for(int i = 0; i < 16; i++) begin
            add_seeded_io(io_obj);
        end

        // finished sequence.
        io_obj.end_last_sequence = 1;

        // broadcast
        out_broadcaster.push(io_obj);

    endtask
endclass
