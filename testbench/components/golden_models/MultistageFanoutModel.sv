import constant_functions_pkg::*;

class MultistageFanoutModel #(type T);
    ////////////////////////////////////////////////////////////////
    // Globally Defined Locally Set Parameters
    localparam STAGES            = multistage_fanout_STAGES           (T::FANOUT_FACTOR, T::FANOUT_SIZE);
    localparam FINAL_FANOUT_SIZE = multistage_fanout_FINAL_FANOUT_SIZE(T::FANOUT_FACTOR, T::STAGES);
    localparam LATENCY           = multistage_fanout_LATENCY          (T::IMMEDIATE_START_FANOUT, T::STAGES);
    
    `MULTISTAGE_FANOUT_IO_IN_STRUCT(T::DATA_WIDTH)
    `MULTISTAGE_FANOUT_IO_OUT_STRUCT(T::DATA_WIDTH, T::FINAL_FANOUT_SIZE)
    
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
        multistage_fanout_io_in_t multistage_fanout_io_in;
        multistage_fanout_io_out_t multistage_fanout_io_out;


        forever begin
            in_queue.pop(io_obj_in);
            io_obj_out = new();

            while(io_obj_in.multistage_fanout_io_in_q.size() > 0) begin
                multistage_fanout_io_in = io_obj_in.multistage_fanout_io_in_q.pop_front();

                if(io_obj_in.idle.pop_front()) begin
                    continue;
                end

                multistage_fanout_io_out.data_o = this.fanout(multistage_fanout_io_in.data_i);
                
                io_obj_out.error_state.push_back(0);
                io_obj_out.multistage_fanout_io_out_q.push_back(multistage_fanout_io_out);
            end
            
            out_broadcaster.push(io_obj_out);
        end
    endtask

    ////////////////////////////////////////////////////////////////
    // Main Functions
    function automatic logic [FINAL_FANOUT_SIZE - 1 : 0][T::DATA_WIDTH - 1 : 0] fanout (logic [T::DATA_WIDTH - 1 : 0] data_i);
        logic [FINAL_FANOUT_SIZE - 1 : 0][T::DATA_WIDTH - 1 : 0] data_o;
        for(int i = 0; i < FINAL_FANOUT_SIZE; i++) begin
            data_o[i] = data_i;
        end
        return data_o;
    endfunction

endclass