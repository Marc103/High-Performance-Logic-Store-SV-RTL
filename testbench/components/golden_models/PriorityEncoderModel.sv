import constant_functions_pkg::*;

class PriorityEncoderModel #(type T);
    `PRIORITY_ENCODER_IO_IN_STRUCT(T::INPUT_DATA_WIDTH)
    `PRIORITY_ENCODER_IO_OUT_STRUCT(T::OUTPUT_DATA_WIDTH)

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
        priority_encoder_io_in_t priority_encoder_io_in;
        priority_encoder_io_out_t priority_encoder_io_out;

        forever begin
            in_queue.pop(io_obj_in);
            io_obj_out = new();

            while(io_obj_in.priority_encoder_io_in_q.size() > 0) begin
                priority_encoder_io_in = io_obj_in.priority_encoder_io_in_q.pop_front();

                if(io_obj_in.idle.pop_front()) begin
                    continue;
                end

                priority_encoder_io_out.priority_encoded_o = this.encode(priority_encoder_io_in.priority_i);
                
                io_obj_out.error_state.push_back(this.error_state);
                io_obj_out.priority_encoder_io_out_q.push_back(priority_encoder_io_out);
            end
            
            out_broadcaster.push(io_obj_out);
        end

    endtask

    ////////////////////////////////////////////////////////////////
    // Main Functions
    function automatic logic [T::OUTPUT_DATA_WIDTH - 1 : 0] encode(
        input logic [T::INPUT_DATA_WIDTH - 1 : 0] priority_vec
    );
        logic [T::OUTPUT_DATA_WIDTH - 1 : 0] encoded;
        encoded = '0;

        for(int i = 0; i < T::INPUT_DATA_WIDTH; i++) begin
            if(priority_vec[i]) begin
                encoded = i[T::OUTPUT_DATA_WIDTH - 1 : 0];
            end
        end

        return encoded;
    endfunction
    
endclass
