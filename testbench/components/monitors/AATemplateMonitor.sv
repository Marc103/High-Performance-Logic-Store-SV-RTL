import constant_functions_pkg::*;

class ???Monitor #(type T, type I);
    `???_IO_OUT_STRUCT(???)

    TriggerableQueueBroadcaster #(T) out_broadcaster;
    I inf;

    function new(TriggerableQueueBroadcaster #(T) out_broadcaster,
                 I inf);
        this.out_broadcaster = out_broadcaster;
        this.inf = inf;
    endfunction

    // 'v' for valid
    // 'l' for latency
    // 'fs' for finish sequencey
    // 'end_ls' for end last sequence

    // index 0 represents input, 1 is 1 cycle later output, 2 is 2 cycle later output...
    logic                      [??? : 0] v_l      = 0; 
    logic                      [??? : 0] end_s_l  = 0; 
    logic                      [??? : 0] end_ls_l = 0;
    ???_io_out_t [??? : 0] ???_out_l;

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

            // latency == 0 handling
            if(T::??? == 0) begin
                if(inf.start_sequence || active_sequence) begin
                    ???
                end
                if(inf.end_sequence) begin
                    active_sequence = 0;
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
                v_l[0]      <= !inf.idle; //otherwise its an idle cycle
                end_ls_l[0] <= inf.end_last_sequence;
                end_s_l[0]  <= inf.end_sequence;
            end

            for(int i = 1; i <= ???; i++) begin
                v_l[i]      <= v_l[i - 1];
                end_s_l[i]  <= end_s_l[i - 1];
                end_ls_l[i] <= end_ls_l[i - 1];  
            end

            ???_out_l[0].data_o <= inf.data_o;
            
            // output pipelining
            for(int i = 1; i <= ???; i++) begin

                // ??? cycles later : data output recording
                if((i == ???) && (v_l[??? - 1])) begin
                    ???
                end else begin 
                    ???
                end 
            end
            
            // for valid commands
            if(v_l[???]) begin
                io_obj.???_io_out_q.push_back(???_out_l[???]);
                if(end_s_l[???]) begin
                    if(end_ls_l[???]) begin
                       io_obj.end_last_sequence = 1; 
                    end

                    this.out_broadcaster.push(io_obj);
                end
            end

            // if last sequence item is an idle cycle
            if(!v_l[???] && end_s_l[???]) begin
                if(end_ls_l[???]) begin
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
