import constant_functions_pkg::*;

class MultistageFanoutMonitor #(type T, type I);
    ////////////////////////////////////////////////////////////////
    // Globally Defined Locally Set Parameters
    localparam STAGES            = multistage_fanout_STAGES           (T::FANOUT_FACTOR, T::FANOUT_SIZE);
    localparam FINAL_FANOUT_SIZE = multistage_fanout_FINAL_FANOUT_SIZE(T::FANOUT_FACTOR, T::STAGES);
    localparam LATENCY           = multistage_fanout_LATENCY          (T::IMMEDIATE_START_FANOUT, T::STAGES);
    
    `MULTISTAGE_FANOUT_IO_OUT_STRUCT(T::DATA_WIDTH, FINAL_FANOUT_SIZE)

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
    logic                      [LATENCY : 0] v_l      = 0; 
    logic                      [LATENCY : 0] end_s_l  = 0; 
    logic                      [LATENCY : 0] end_ls_l = 0;
    multistage_fanout_io_out_t [LATENCY : 0] multistage_fanout_out_l;

    logic active_sequence = 0;
    logic finish_sequence = 0;

    task automatic run();
        T io_obj;
    
        forever begin
            @(negedge inf.clk_i); 
            
            if(inf.start_sequence) begin
                io_obj = new();
                active_sequence <= 1;   
            end else begin
                active_sequence <= active_sequence;
            end

            if(inf.end_sequence) begin
                finish_sequence <= 1;
            end else begin
                finish_sequence <= 0;
            end

            // input tracking pipeline
            if(inf.start_sequence || active_sequence) begin
                v_l[0]      <= !inf.idle; //otherwise its an idle cycle
                end_ls_l[0] <= inf.end_last_sequence;
                end_s_l[0]  <= inf.end_sequence;
            end

            for(int i = 1; i <= LATENCY; i++) begin
                v_l[i]      <= v_l[i - 1];
                end_s_l[i]  <= end_s_l[i - 1];
                end_ls_l[i] <= end_ls_l[i - 1];  
            end

            multistage_fanout_out_l[0].data_o <= inf.data_o;
            
            // output pipelining
            for(int i = 1; i <= LATENCY; i++) begin

                // LATENCY cycles later : data output recording
                if((i == LATENCY) && (v_l[LATENCY - 1])) begin
                    multistage_fanout_out_l[i].data_o   <= inf.data_o;
                end else begin 
                    multistage_fanout_out_l[i].data_o   <= multistage_fanout_out_l[i-1].data_o;
                end 
            end
            
            // for valid commands
            if(v_l[LATENCY]) begin
                io_obj.multistage_fanout_io_out_q.push_back(multistage_fanout_out_l[LATENCY]);
                if(end_s_l[LATENCY]) begin
                    if(end_ls_l[LATENCY]) begin
                       io_obj.end_last_sequence = 1; 
                    end

                    this.out_broadcaster.push(io_obj);
                end
            end

            // if last sequence item is an idle cycle
            if(!v_l[LATENCY] && end_s_l[LATENCY]) begin
                if(end_ls_l[LATENCY]) begin
                    io_obj.end_last_sequence = 1;
                end
                this.out_broadcaster.push(io_obj);
            end

            if(finish_sequence) begin
                active_sequence <= 0;
                finish_sequence <= 0;
            end    
        end
    endtask
endclass