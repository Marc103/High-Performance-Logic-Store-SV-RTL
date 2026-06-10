import constant_functions_pkg::*;

class QueueMonitor #(type T, type I);
    `QUEUE_IO_OUT_STRUCT(T::NUMBER_OF_QUEUES, T::DATA_WIDTH, T::ADDR_WIDTH) 

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
    logic          [T::READ_LATENCY : 0] v_l      = 0; 
    logic          [T::READ_LATENCY : 0] end_s_l  = 0; 
    logic          [T::READ_LATENCY : 0] end_ls_l = 0;
    logic          [T::READ_LATENCY : 0] push_l   = 0;
    logic          [T::READ_LATENCY : 0] pop_l   = 0;
    logic          [T::READ_LATENCY : 0] rst_l    = 0;
    queue_io_out_t [T::READ_LATENCY : 0] queue_io_out_l;

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
                v_l[0]      <= !inf.idle; //otherwise its a 'ignore'
                end_ls_l[0] <= inf.end_last_sequence; 
                end_s_l[0]  <= inf.end_sequence;
                push_l[0]   <= inf.push_i;
                pop_l[0]    <= inf.pop_i;
                rst_l[0]    <= inf.rst_i;
            end

            for(int i = 1; i <= T::READ_LATENCY; i++) begin
                v_l[i]      <= v_l[i - 1]; 
                end_s_l[i]  <= end_s_l[i - 1];
                end_ls_l[i] <= end_ls_l[i - 1]; 
                push_l[i]   <= push_l[i - 1];
                pop_l[i]    <= pop_l[i - 1];
                rst_l[i]    <= rst_l[i - 1];
            end

            queue_io_out_l[0].full_o      <= inf.full_o;
            queue_io_out_l[0].empty_o     <= inf.empty_o;
            queue_io_out_l[0].less_than_o <= inf.less_than_o;
            queue_io_out_l[0].more_than_o <= inf.more_than_o;
            queue_io_out_l[0].rd_data_o   <= inf.rd_data_o;
            
            // output pipelining
            for(int i = 1; i <= T::READ_LATENCY; i++) begin
                // 1 cycle later : condition recording
                if((i == 1 && (v_l[0]))) begin
                    queue_io_out_l[i].full_o      <= inf.full_o;
                    queue_io_out_l[i].empty_o     <= inf.empty_o;
                    queue_io_out_l[i].less_than_o <= inf.less_than_o;
                    queue_io_out_l[i].more_than_o <= inf.more_than_o;
                end else begin
                    queue_io_out_l[i].full_o      <= queue_io_out_l[i-1].full_o;
                    queue_io_out_l[i].empty_o     <= queue_io_out_l[i-1].empty_o;
                    queue_io_out_l[i].less_than_o <= queue_io_out_l[i-1].less_than_o;
                    queue_io_out_l[i].more_than_o <= queue_io_out_l[i-1].more_than_o;
                end

                // READ_LATENCY cycles later : read output recording
                if((i == T::READ_LATENCY) && (v_l[T::READ_LATENCY - 1])) begin
                    if((push_l[T::READ_LATENCY - 1] && (!pop_l[T::READ_LATENCY - 1])) || rst_l[T::READ_LATENCY - 1]) begin
                        queue_io_out_l[i].rd_data_o   <= 'x;
                    end else begin
                        queue_io_out_l[i].rd_data_o   <= inf.rd_data_o;
                    end
                end else if(i == T::READ_LATENCY) begin 
                    queue_io_out_l[i].rd_data_o   <= queue_io_out_l[i-1].rd_data_o;
                end 
            end
            
            // for valid commands
            if(v_l[T::READ_LATENCY]) begin
                io_obj.queue_io_out_q.push_back(queue_io_out_l[T::READ_LATENCY]);
                if(end_s_l[T::READ_LATENCY]) begin
                    if(end_ls_l[T::READ_LATENCY]) begin
                       io_obj.end_last_sequence = 1; 
                    end 
                    this.out_broadcaster.push(io_obj);
                end
            end

            // if last sequence item is an idle cycle
            if(!v_l[T::READ_LATENCY] && end_s_l[T::READ_LATENCY]) begin
                if(end_ls_l[T::READ_LATENCY]) begin
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
