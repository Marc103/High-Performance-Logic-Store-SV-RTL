import constant_functions_pkg::*;

class MultistageMuxMonitor #(type T, type I);
    `MULTISTAGE_MUX_IO_OUT_STRUCT(T::DATA_WIDTH)

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

    // index 0 represents input, 1 is 1 cycle later output, 2 is 2 cycle later output...
    logic                  [T::LATENCY : 0] v_l      = 0; 
    logic                  [T::LATENCY : 0] end_s_l  = 0; 
    logic                  [T::LATENCY : 0] end_ls_l = 0;

    logic active_sequence = 0;
    logic finish_sequence = 0;

    task automatic push_if_done(
        ref T io_obj,
        input logic valid,
        input logic end_sequence,
        input logic end_last_sequence,
        input multistage_mux_io_out_t multistage_mux_io_out
    );
        if(valid) begin
            io_obj.multistage_mux_io_out_q.push_back(multistage_mux_io_out);
        end

        if(end_sequence) begin
            if(end_last_sequence) begin
                io_obj.end_last_sequence = 1;
            end
            this.out_broadcaster.push(io_obj);
        end
    endtask

    task automatic run();
        T io_obj;
        multistage_mux_io_out_t current_out;
        logic input_valid;
        logic input_end_sequence;
        logic input_end_last_sequence;
    
        forever begin
            @(negedge inf.clk_i); 
            
            if(inf.start_sequence) begin
                io_obj = new();
                active_sequence = 1;   
            end else begin
                active_sequence = active_sequence;
            end

            if(T::LATENCY == 0) begin
                current_out.data_o = inf.data_o;
                if(inf.start_sequence || active_sequence) begin
                    push_if_done(
                        io_obj,
                        !inf.idle,
                        inf.end_sequence,
                        inf.end_last_sequence,
                        current_out
                    );
                end

                if(inf.end_sequence) begin
                    active_sequence = 0;
                end
                continue;
            end

            input_valid = 0;
            input_end_sequence = 0;
            input_end_last_sequence = 0;

            if(inf.start_sequence || active_sequence) begin
                input_valid = !inf.idle;
                input_end_sequence = inf.end_sequence;
                input_end_last_sequence = inf.end_last_sequence;
            end

            // input tracking pipeline
            for(int i = T::LATENCY; i > 0; i--) begin
                v_l[i]      = v_l[i - 1];
                end_s_l[i]  = end_s_l[i - 1];
                end_ls_l[i] = end_ls_l[i - 1];  
            end

            v_l[0]      = input_valid;
            end_s_l[0]  = input_end_sequence;
            end_ls_l[0] = input_end_last_sequence;

            current_out.data_o = inf.data_o;

            if(input_end_sequence) begin
                finish_sequence = 1;
            end
            
            // for valid commands
            if(v_l[T::LATENCY]) begin
                io_obj.multistage_mux_io_out_q.push_back(current_out);
                if(end_s_l[T::LATENCY]) begin
                    if(end_ls_l[T::LATENCY]) begin
                       io_obj.end_last_sequence = 1; 
                    end
                    $display("%p", io_obj);
                    this.out_broadcaster.push(io_obj);
                end
            end

            // if last sequence item is an idle cycle
            if(!v_l[T::LATENCY] && end_s_l[T::LATENCY]) begin
                if(end_ls_l[T::LATENCY]) begin
                    io_obj.end_last_sequence = 1;
                end
                $display("%p", io_obj);
                this.out_broadcaster.push(io_obj);
            end

            if(finish_sequence) begin
                active_sequence = 0;
                finish_sequence = 0;
            end    
        end
    endtask

endclass
