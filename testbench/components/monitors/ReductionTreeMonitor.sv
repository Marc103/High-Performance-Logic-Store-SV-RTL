import constant_functions_pkg::*;

class ReductionTreeMonitor #(type T, type I);
    `REDUCTION_TREE_IO_OUT_STRUCT

    TriggerableQueueBroadcaster #(T) out_broadcaster;
    I inf;

    function new(TriggerableQueueBroadcaster #(T) out_broadcaster,
                 I inf);
        this.out_broadcaster = out_broadcaster;
        this.inf = inf;
    endfunction

    // 'v' for valid
    // 'l' for latency
    // 'end_ls' for end last sequence

    // index 0 represents input, 1 is 1 cycle later output, 2 is 2 cycles later output...
    logic                    [T::LATENCY : 0] v_l      = 0; 
    logic                    [T::LATENCY : 0] end_s_l  = 0; 
    logic                    [T::LATENCY : 0] end_ls_l = 0;
    reduction_tree_io_out_t  [T::LATENCY : 0] reduction_tree_out_l;

    logic active_sequence = 0;
    logic finish_sequence = 0;

    task automatic run();
        T io_obj;
        reduction_tree_io_out_t reduction_tree_io_out;
    
        forever begin
            @(negedge inf.clk_i); 
            
            if(inf.start_sequence) begin
                io_obj = new();
                active_sequence = 1;   
            end else begin
                active_sequence = active_sequence;
            end

            // latency == 0 handling
            if(T::LATENCY == 0) begin
                if(inf.start_sequence || active_sequence) begin
                    if(!inf.idle) begin
                        reduction_tree_io_out.reduced_o = inf.reduced_o;
                        io_obj.reduction_tree_io_out_q.push_back(reduction_tree_io_out);
                    end

                    if(inf.end_sequence) begin
                        if(inf.end_last_sequence) begin
                            io_obj.end_last_sequence = 1;
                        end
                        this.out_broadcaster.push(io_obj);
                        active_sequence = 0;
                    end
                end
                continue;
            end

            if(inf.end_sequence) begin
                finish_sequence = 1;
            end else begin
                finish_sequence = 0;
            end

            // input tracking pipeline
            if(inf.start_sequence || active_sequence) begin
                v_l[0]      <= !inf.idle; // otherwise its an idle cycle
                end_ls_l[0] <= inf.end_last_sequence;
                end_s_l[0]  <= inf.end_sequence;
            end

            for(int i = 1; i <= T::LATENCY; i++) begin
                v_l[i]      <= v_l[i - 1];
                end_s_l[i]  <= end_s_l[i - 1];
                end_ls_l[i] <= end_ls_l[i - 1];  
            end

            reduction_tree_out_l[0].reduced_o <= inf.reduced_o;
            
            // output pipelining
            for(int i = 1; i <= T::LATENCY; i++) begin
                if((i == T::LATENCY) && (v_l[i - 1])) begin
                    reduction_tree_out_l[i].reduced_o <= inf.reduced_o;
                end else begin 
                    reduction_tree_out_l[i].reduced_o <= reduction_tree_out_l[i - 1].reduced_o;
                end 
            end
            
            // for valid commands
            if(v_l[T::LATENCY]) begin
                io_obj.reduction_tree_io_out_q.push_back(reduction_tree_out_l[T::LATENCY]);
                if(end_s_l[T::LATENCY]) begin
                    if(end_ls_l[T::LATENCY]) begin
                       io_obj.end_last_sequence = 1; 
                    end

                    this.out_broadcaster.push(io_obj);
                end
            end

            // if last sequence item is an idle cycle
            if(!v_l[T::LATENCY] && end_s_l[T::LATENCY]) begin
                if(end_ls_l[T::LATENCY]) begin
                    io_obj.end_last_sequence = 1;
                end
                this.out_broadcaster.push(io_obj);
            end

            if(finish_sequence) begin
                active_sequence = 0;
                finish_sequence = 0;
            end    
        end
    endtask

endclass
