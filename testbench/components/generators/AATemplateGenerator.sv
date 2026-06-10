import constant_functions_pkg::*;

class ???Generator #(type T);
    `???_IO_IN_STRUCT(???)

    TriggerableQueueBroadcaster #(T) out_broadcaster;

    int seed;

    function new(TriggerableQueueBroadcaster #(T) out_broadcaster);
        this.out_broadcaster = out_broadcaster;
        seed = ???;
    endfunction

    task automatic add_io(
        ref T io_obj,
        input logic idle,
        ???
    );
        ???_io_in_t ???_io_in;

        ???

        this.seed = ???;

        io_obj.???_io_in_q.push_back(???_io_in);
        io_obj.idle.push_back(idle);
    endtask;

    task automatic run();
        T io_obj;
        io_obj = new();

        add_io(io_obj, ???)
        
        ???

        // finished sequence.
        io_obj.end_last_sequence = ???;

        // broadcast
        out_broadcaster.push(io_obj);

    endtask
endclass
