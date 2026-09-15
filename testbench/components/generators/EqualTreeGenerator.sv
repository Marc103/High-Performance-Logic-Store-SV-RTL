import constant_functions_pkg::*;

class EqualTreeGenerator #(type T);
    `EQUAL_TREE_IO_IN_STRUCT(T::DATA_WIDTH)

    TriggerableQueueBroadcaster #(T) out_broadcaster;

    int seed;

    function new(TriggerableQueueBroadcaster #(T) out_broadcaster);
        this.out_broadcaster = out_broadcaster;
        seed = 83;
    endfunction

    task automatic add_io(
        ref T io_obj,
        input logic idle,
        input logic [T::DATA_WIDTH - 1 : 0] data_a,
        input logic [T::DATA_WIDTH - 1 : 0] data_b
    );
        equal_tree_io_in_t equal_tree_io_in;

        equal_tree_io_in.data_a_i = data_a;
        equal_tree_io_in.data_b_i = data_b;

        io_obj.equal_tree_io_in_q.push_back(equal_tree_io_in);
        io_obj.idle.push_back(idle);
    endtask

    task automatic add_seeded_io(ref T io_obj, input bit make_equal);
        logic [T::DATA_WIDTH - 1 : 0] data_a;
        logic [T::DATA_WIDTH - 1 : 0] data_b;
        int mismatch_index;

        for(int i = 0; i < T::DATA_WIDTH; i++) begin
            data_a[i] = this.seed[i % 32] ^ i[0];
        end

        data_b = data_a;
        if(!make_equal) begin
            mismatch_index = this.seed % T::DATA_WIDTH;
            data_b[mismatch_index] = ~data_b[mismatch_index];
        end

        this.seed++;
        add_io(io_obj, 0, data_a, data_b);
    endtask

    task automatic run();
        T io_obj;
        io_obj = new();

        // Directed equality, inequality, and boundary-bit tests.
        add_io(io_obj, 0, '0, '0);
        add_io(io_obj, 0, '1, '1);
        add_io(io_obj, 0, '0, '1);
        add_io(io_obj, 0, 'h1, 'h1);
        add_io(io_obj, 0, 'h1, '0);

        // Idle gaps verify that sequence tracking remains aligned to the DUT.
        add_io(io_obj, 1, '0, '0);

        for(int i = 0; i < 32; i++) begin
            add_seeded_io(io_obj, (i % 3) == 0);
            if(i == 14) begin
                add_io(io_obj, 1, '0, '0);
            end
        end

        // finished sequence.
        io_obj.end_last_sequence = 1;

        // broadcast
        out_broadcaster.push(io_obj);

    endtask
endclass
