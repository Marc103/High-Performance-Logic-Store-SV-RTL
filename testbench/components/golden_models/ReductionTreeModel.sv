import constant_functions_pkg::*;

class ReductionTreeModel #(type T);
    `REDUCTION_TREE_IO_IN_STRUCT(T::DATA_WIDTH)
    `REDUCTION_TREE_IO_OUT_STRUCT

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
        reduction_tree_io_in_t reduction_tree_io_in;
        reduction_tree_io_out_t reduction_tree_io_out;

        forever begin
            in_queue.pop(io_obj_in);
            io_obj_out = new();

            while(io_obj_in.reduction_tree_io_in_q.size() > 0) begin
                reduction_tree_io_in = io_obj_in.reduction_tree_io_in_q.pop_front();

                if(io_obj_in.idle.pop_front()) begin
                    continue;
                end

                reduction_tree_io_out.reduced_o = this.reduce_data(reduction_tree_io_in.data_i);
                
                io_obj_out.error_state.push_back(this.error_state);
                io_obj_out.reduction_tree_io_out_q.push_back(reduction_tree_io_out);
            end
            
            out_broadcaster.push(io_obj_out);
        end

    endtask

    ////////////////////////////////////////////////////////////////
    // Main Functions
    function automatic logic reduce_data(input logic [T::DATA_WIDTH - 1 : 0] data);
        this.error_state = 0;

        if(T::GATE == 0) begin
            return &data;
        end else if(T::GATE == 1) begin
            return |data;
        end else if(T::GATE == 2) begin
            return ^data;
        end else begin
            this.error_state = 1;
            return 'x;
        end
    endfunction
    
endclass
