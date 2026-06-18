import constant_functions_pkg::*;

class PriorityEncoderGenerator #(type T);
    `PRIORITY_ENCODER_IO_IN_STRUCT(T::INPUT_DATA_WIDTH)

    TriggerableQueueBroadcaster #(T) out_broadcaster;

    int seed;

    function new(TriggerableQueueBroadcaster #(T) out_broadcaster);
        this.out_broadcaster = out_broadcaster;
        seed = 29;
    endfunction

    task automatic add_io(
        ref T io_obj,
        input logic idle,
        input logic [T::INPUT_DATA_WIDTH - 1 : 0] priority_vec
    );
        priority_encoder_io_in_t priority_encoder_io_in;

        priority_encoder_io_in.priority_i = priority_vec;

        io_obj.priority_encoder_io_in_q.push_back(priority_encoder_io_in);
        io_obj.idle.push_back(idle);
    endtask

    task automatic add_seeded_io(ref T io_obj);
        logic [T::INPUT_DATA_WIDTH - 1 : 0] priority_vec;
        priority_vec = '0;

        for(int i = 0; i < T::INPUT_DATA_WIDTH; i++) begin
            if(((i + seed) % 3) == 0) begin
                priority_vec[i] = 1'b1;
            end
        end

        seed++;
        add_io(io_obj, 0, priority_vec);
    endtask

    task automatic run();
        T io_obj;
        logic [T::INPUT_DATA_WIDTH - 1 : 0] priority_vec;
        io_obj = new();

        add_io(io_obj, 0, '0);
        add_io(io_obj, 0, {{(T::INPUT_DATA_WIDTH - 1){1'b0}}, 1'b1});
        add_io(io_obj, 0, {1'b1, {(T::INPUT_DATA_WIDTH - 1){1'b0}}});
        add_io(io_obj, 0, '1);

        for(int i = 0; i < T::INPUT_DATA_WIDTH; i++) begin
            priority_vec = '0;
            priority_vec[i] = 1'b1;
            add_io(io_obj, 0, priority_vec);
        end

        // idle gap to verify sequence tracking
        add_io(io_obj, 1, '0);

        for(int i = 0; i < 8; i++) begin
            add_seeded_io(io_obj);
        end

        // finished sequence.
        io_obj.end_last_sequence = 1;

        // broadcast
        out_broadcaster.push(io_obj);
    endtask
endclass
