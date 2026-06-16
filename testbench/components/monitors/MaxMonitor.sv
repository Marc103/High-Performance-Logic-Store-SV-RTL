import constant_functions_pkg::*;

class MaxMonitor #(type T, type I);
    `MAX_IO_OUT_STRUCT(T::DATA_WIDTH)

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
    logic        [T::LATENCY : 0] v_l      = 0; 
    logic        [T::LATENCY : 0] end_s_l  = 0; 
    logic        [T::LATENCY : 0] end_ls_l = 0;
    max_io_out_t [T::LATENCY : 0] max_out_l;

    logic active_sequence = 0;
    logic finish_sequence = 0;

    task automatic run();
        T io_obj;
    
        forever begin
            @(negedge inf.clk_i); 
            
            if(inf.start_sequence) begin
                io_obj = new();
                active_sequence = 1;   
            end else begin
                active_sequence = active_sequence;
            end

            if(inf.end_sequence) begin
                finish_sequence = 1;
            end else begin
                finish_sequence = 0;
            end

            // input tracking pipeline
            if(inf.start_sequence || active_sequence) begin
                v_l[0]      <= !inf.idle;
                end_ls_l[0] <= inf.end_last_sequence;
                end_s_l[0]  <= inf.end_sequence;
            end

            for(int i = 1; i <= T::LATENCY; i++) begin
                v_l[i]      <= v_l[i - 1];
                end_s_l[i]  <= end_s_l[i - 1];
                end_ls_l[i] <= end_ls_l[i - 1];  
            end

            max_out_l[0].data_o <= inf.data_o;
            
            // output pipelining
            for(int i = 1; i <= T::LATENCY; i++) begin
                if((i == T::LATENCY) && (v_l[T::LATENCY - 1])) begin
                    max_out_l[i].data_o <= inf.data_o;
                end else begin 
                    max_out_l[i].data_o <= max_out_l[i - 1].data_o;
                end 
            end
            
            // for valid commands
            if(v_l[T::LATENCY]) begin
                io_obj.max_io_out_q.push_back(max_out_l[T::LATENCY]);
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
