import constant_functions_pkg::*;

class AlignerMonitor #(type T, type I);
    `ALIGNER_IO_OUT_STRUCT(T::DATA_WIDTH, T::SIZE, T::PRIORITY_ENCODER_OUTPUT_DATA_WIDTH)

    TriggerableQueueBroadcaster #(T) out_broadcaster;
    I inf;

    function new(
        TriggerableQueueBroadcaster #(T) out_broadcaster,
        I inf
    );
        this.out_broadcaster = out_broadcaster;
        this.inf = inf;
    endfunction

    logic [T::LATENCY : 0] v_l = 0;
    logic [T::LATENCY : 0] end_s_l = 0;
    logic [T::LATENCY : 0] end_ls_l = 0;

    logic active_sequence = 0;
    logic finish_sequence = 0;

    task automatic push_if_done(
        ref T io_obj,
        input logic valid,
        input logic end_sequence,
        input logic end_last_sequence,
        input aligner_io_out_t aligner_io_out
    );
        if(valid) begin
            io_obj.aligner_io_out_q.push_back(aligner_io_out);
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
        aligner_io_out_t current_out;
        logic input_valid;
        logic input_end_sequence;
        logic input_end_last_sequence;

        forever begin
            @(negedge inf.clk_i);

            if(inf.start_sequence) begin
                io_obj = new();
                active_sequence = 1;
            end

            current_out.aligned_o = inf.aligned_o;
            current_out.matched_o = inf.matched_o;
            current_out.selector_o = inf.selector_o;

            if(T::LATENCY == 0) begin
                if(inf.start_sequence || active_sequence) begin
                    push_if_done(io_obj, !inf.idle, inf.end_sequence, inf.end_last_sequence, current_out);
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

            for(int i = T::LATENCY; i > 0; i--) begin
                v_l[i] = v_l[i - 1];
                end_s_l[i] = end_s_l[i - 1];
                end_ls_l[i] = end_ls_l[i - 1];
            end

            v_l[0] = input_valid;
            end_s_l[0] = input_end_sequence;
            end_ls_l[0] = input_end_last_sequence;

            push_if_done(
                io_obj,
                v_l[T::LATENCY],
                end_s_l[T::LATENCY],
                end_ls_l[T::LATENCY],
                current_out
            );

            if(input_end_sequence) begin
                finish_sequence = 1;
            end

            if(finish_sequence) begin
                active_sequence = 0;
                finish_sequence = 0;
            end
        end
    endtask
endclass
