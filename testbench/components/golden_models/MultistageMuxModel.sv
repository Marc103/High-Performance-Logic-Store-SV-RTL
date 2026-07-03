import constant_functions_pkg::*;

class MultistageMuxModel #(type T);
    `MULTISTAGE_MUX_IO_IN_STRUCT(T::DATA_WIDTH, T::SIZE, T::SELECTOR_WIDTH)
    `MULTISTAGE_MUX_IO_OUT_STRUCT(T::DATA_WIDTH)

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
        multistage_mux_io_in_t multistage_mux_io_in;
        multistage_mux_io_out_t multistage_mux_io_out;

        forever begin
            in_queue.pop(io_obj_in);
            io_obj_out = new();

            while(io_obj_in.multistage_mux_io_in_q.size() > 0) begin
                multistage_mux_io_in = io_obj_in.multistage_mux_io_in_q.pop_front();

                if(io_obj_in.idle.pop_front()) begin
                    continue;
                end

                multistage_mux_io_out.data_o = mux(multistage_mux_io_in.data_i, multistage_mux_io_in.sel_i);
                
                io_obj_out.error_state.push_back(0);
                io_obj_out.multistage_mux_io_out_q.push_back(multistage_mux_io_out);
            end
            
            out_broadcaster.push(io_obj_out);
        end

    endtask

    ////////////////////////////////////////////////////////////////
    // Main Functions
    function automatic logic [T::DATA_WIDTH - 1 : 0] mux(
        input logic [T::SIZE - 1 : 0][T::DATA_WIDTH - 1 : 0] data,
        input logic [T::SELECTOR_WIDTH - 1 : 0] sel
    );
        return data[sel];
    endfunction
    
endclass
