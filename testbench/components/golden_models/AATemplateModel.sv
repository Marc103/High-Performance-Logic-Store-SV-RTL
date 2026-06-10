import constant_functions_pkg::*;

class ???Model #(type T);
    `???_IO_IN_STRUCT(???)
    `???_IO_OUT_STRUCT(???)

    TriggerableQueue #(T) in_queue;
    TriggerableQueueBroadcaster #(T) out_broadcaster;

    protected logic unsigned [7:0] error_state;

    function new(
        TriggerableQueue #(T) in_queue,
        TriggerableQueueBroadcaster #(T) out_broadcaster
    );
        this.in_queue = in_queue;
        this.out_broadcaster = out_broadcaster;
        this.error_state = 0;
    endfunction

    task automatic run();
        T io_obj_in;
        T io_obj_out;
        ???_io_in_t ???_io_in;
        ???_io_out_t ???_io_out;

        forever begin
            in_queue.pop(io_obj_in);
            io_obj_out = new();

            while(io_obj_in.???_io_in_q.size() > 0) begin
                ???_io_in = io_obj_in.???_io_in_q.pop_front();

                if(io_obj_in.idle.pop_front()) begin
                    continue;
                end

                ???
                
                io_obj_out.error_state.push_back(0);
                io_obj_out.???_io_out_q.push_back(???_io_out);
            end
            
            out_broadcaster.push(io_obj_out);
        end

    endtask

    ////////////////////////////////////////////////////////////////
    // Main Functions
    ???
    
endclass
