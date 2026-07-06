import constant_functions_pkg::*;

class EqualModel #(type T);
    `EQUAL_IO_IN_STRUCT(T::DATA_WIDTH)
    `EQUAL_IO_OUT_STRUCT

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
        equal_io_in_t equal_io_in;
        equal_io_out_t equal_io_out;

        forever begin
            in_queue.pop(io_obj_in);
            io_obj_out = new();

            while(io_obj_in.equal_io_in_q.size() > 0) begin
                equal_io_in = io_obj_in.equal_io_in_q.pop_front();

                if(io_obj_in.idle.pop_front()) begin
                    continue;
                end

                equal_io_out.eq_o = this.equal_data(equal_io_in.data_a_i, equal_io_in.data_b_i);
                
                io_obj_out.error_state.push_back(this.error_state);
                io_obj_out.equal_io_out_q.push_back(equal_io_out);
            end
            
            out_broadcaster.push(io_obj_out);
        end
    endtask

    ////////////////////////////////////////////////////////////////
    // Main Functions
    function automatic logic equal_data(
        input logic [T::DATA_WIDTH - 1 : 0] data_a,
        input logic [T::DATA_WIDTH - 1 : 0] data_b
    );
        return (data_a == data_b);
    endfunction
    
endclass
