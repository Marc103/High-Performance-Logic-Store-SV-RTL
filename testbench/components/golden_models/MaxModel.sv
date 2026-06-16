import constant_functions_pkg::*;

class MaxModel #(type T);
    `MAX_IO_IN_STRUCT(T::DATA_WIDTH)
    `MAX_IO_OUT_STRUCT(T::DATA_WIDTH)

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
        max_io_in_t max_io_in;
        max_io_out_t max_io_out;

        forever begin
            in_queue.pop(io_obj_in);
            io_obj_out = new();

            while(io_obj_in.max_io_in_q.size() > 0) begin
                max_io_in = io_obj_in.max_io_in_q.pop_front();

                if(io_obj_in.idle.pop_front()) begin
                    continue;
                end

                max_io_out.data_o = this.max_data(max_io_in.data_a_i, max_io_in.data_b_i);
                
                io_obj_out.error_state.push_back(this.error_state);
                io_obj_out.max_io_out_q.push_back(max_io_out);
            end
            
            out_broadcaster.push(io_obj_out);
        end
    endtask

    ////////////////////////////////////////////////////////////////
    // Main Functions
    function automatic logic [T::DATA_WIDTH - 1 : 0] max_data(
        input logic [T::DATA_WIDTH - 1 : 0] data_a,
        input logic [T::DATA_WIDTH - 1 : 0] data_b
    );
        logic signed [T::DATA_WIDTH - 1 : 0] data_a_s;
        logic signed [T::DATA_WIDTH - 1 : 0] data_b_s;
        logic unsigned [T::DATA_WIDTH - 1 : 0] data_a_us;
        logic unsigned [T::DATA_WIDTH - 1 : 0] data_b_us;

        data_a_s = data_a;
        data_b_s = data_b;
        data_a_us = data_a;
        data_b_us = data_b;

        if(T::SIGNED == 1) begin
            return (data_b_s < data_a_s) ? data_a : data_b;
        end

        return (data_b_us < data_a_us) ? data_a : data_b;
    endfunction
    
endclass
