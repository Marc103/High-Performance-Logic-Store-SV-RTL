import constant_functions_pkg::*;

class QueueMonitor #(type T, type I);
    ////////////////////////////////////////////////////////////////
    // Globally Defined Locally Set Parameters
    localparam DATA_DEPTH    = queue_DATA_DEPTH    (T::ADDR_WIDTH);
    localparam READ_LATENCY  = queue_READ_LATENCY  (T::REGISTERED_IN, T::REGISTERED_IN_BRAM);
    localparam WRITE_LATENCY = queue_WRITE_LATENCY (T::REGISTERED_IN, T::REGISTERED_IN_BRAM, T::READ_THEN_WRITE);
 
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

    logic          [READ_LATENCY : 0][0:0] v_l; // +1 size for input
    logic          [READ_LATENCY : 0][0:0] end_s_l; 
    logic          [READ_LATENCY : 0][0:0] end_ls_l;
    queue_io_out_t [READ_LATENCY : 0]  queue_io_out_l;

    task automatic run();
        T io_obj;

        logic active_sequence = 0;
        logic finish_sequence = 0;
    
        forever begin
            @(negedge inf.clk_i); 
            
            if(inf.start_sequence) begin
                io_obj = new();
                active_sequence = 1;
                $display("start of sequence detected.");     
            end

            if(inf.end_sequence) begin
                finish_sequence = 1;
                $display("end of sequence detected.");
            end 

            if(active_sequence) begin
                v_l[0]      <= inf.pop_i | inf.push_i | inf.rst_i; //otherwise its a 'ignore'
                end_s_l[0]  <= inf.end_sequence;
                end_ls_l[0] <= inf.end_last_sequence;
            end

            for(int i = 1; i <= READ_LATENCY; i++) begin
                v_l[i]      <= v_l[i - 1]; 
                end_s_l[i]  <= end_s_l[i - 1];
                end_ls_l[i] <= end_ls_l[i - 1]; 
            end
                
            queue_io_out_l[1].full_o      <= inf.full_o;
            queue_io_out_l[1].empty_o     <= inf.empty_o;
            queue_io_out_l[1].less_than_o <= inf.less_than_o;
            queue_io_out_l[1].more_than_o <= inf.more_than_o;
            queue_io_out_l[1].rd_data_o   <= inf.rd_data_o;

            for(int i = 2; i <= READ_LATENCY; i++) begin
                if(i == READ_LATENCY) begin
                    queue_io_out_l[i].full_o      <= queue_io_out_l[i-1].full_o;
                    queue_io_out_l[i].empty_o     <= queue_io_out_l[i-1].empty_o;
                    queue_io_out_l[i].less_than_o <= queue_io_out_l[i-1].less_than_o;
                    queue_io_out_l[i].more_than_o <= queue_io_out_l[i-1].more_than_o;
                    queue_io_out_l[i].rd_data_o   <= inf.rd_data_o;
                end else begin
                    queue_io_out_l[i] <= queue_io_out_l[i-1];
                end 
            end
            
            if(v_l[READ_LATENCY]) begin
                io_obj.queue_io_out_q.push_back(queue_io_out_l[READ_LATENCY]);
                if(end_s_l[READ_LATENCY]) begin
                    if(end_ls_l[READ_LATENCY]) begin
                       io_obj.end_last_sequence = 1; 
                       $display("io_obj end of last sequence detected");
                    end 
                    this.out_broadcaster.push(io_obj);
                    $display("io_obj pushed out to scoreboard");
                end
            end

            if(finish_sequence) begin
                active_sequence = 0;
                finish_sequence = 0;
            end    
        end
    endtask
endclass