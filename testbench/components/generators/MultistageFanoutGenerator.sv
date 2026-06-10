import constant_functions_pkg::*;

class MultistageFanoutGenerator #(type T);
    `MULTISTAGE_FANOUT_IO_IN_STRUCT(T::DATA_WIDTH)

    TriggerableQueueBroadcaster #(T) out_broadcaster;

    int seed;

    function new(TriggerableQueueBroadcaster #(T) out_broadcaster);
        this.out_broadcaster = out_broadcaster;
        seed = 38;
    endfunction

    task automatic add_io(
        ref T io_obj,
        input logic idle
    );
        multistage_fanout_io_in_t multistage_fanout_io_in;

        multistage_fanout_io_in.data_i = this.seed;
        this.seed++;

        io_obj.multistage_fanout_io_in_q.push_back(multistage_fanout_io_in);
        io_obj.idle.push_back(idle);
    endtask;

    
    task automatic run();
        T io_obj;
        io_obj = new();

        for(int i = 0; i < 10; i++) begin
            if(i % 3 == 0) begin
                add_io(io_obj, 1);
            end else begin
                add_io(io_obj, 0);
            end
        end
        $display();

        // finished sequence.
        io_obj.end_last_sequence = 1;

        // broadcast
        out_broadcaster.push(io_obj);

    endtask
endclass
