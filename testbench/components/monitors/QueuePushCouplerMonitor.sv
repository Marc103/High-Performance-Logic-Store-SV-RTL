import constant_functions_pkg::*;

class QueuePushCouplerMonitor #(type T, type I);
    `QUEUE_PUSH_COUPLER_IO_OUT_STRUCT(T::DATA_WIDTH, T::ADDR_WIDTH)

    TriggerableQueueBroadcaster #(T) out_broadcaster;
    I inf;

    logic active_sequence = 0;
    logic pending_cycle = 0;
    logic pending_valid = 0;
    logic pending_end_sequence = 0;
    logic pending_end_last_sequence = 0;

    function new(
        TriggerableQueueBroadcaster #(T) out_broadcaster,
        I inf
    );
        this.out_broadcaster = out_broadcaster;
        this.inf = inf;
    endfunction

    task automatic capture_output(ref T io_obj);
        queue_push_coupler_io_out_t queue_push_coupler_io_out;

        queue_push_coupler_io_out.ready_o = inf.ready_o;
        queue_push_coupler_io_out.burstready_o = inf.burstready_o;
        queue_push_coupler_io_out.wr_data_o = inf.wr_data_o;
        queue_push_coupler_io_out.push_o = inf.push_o;
        queue_push_coupler_io_out.more_than_or_eq_o = inf.more_than_or_eq_o;
        io_obj.queue_push_coupler_io_out_q.push_back(queue_push_coupler_io_out);
    endtask

    task automatic run();
        T io_obj;

        forever begin
            @(negedge inf.wr_clk_i);

            if(inf.start_sequence) begin
                io_obj = new();
                active_sequence = 1;
            end

            if(T::LATENCY == 0) begin
                if(active_sequence && !inf.idle) begin
                    capture_output(io_obj);
                end

                if(active_sequence && inf.end_sequence) begin
                    io_obj.end_last_sequence = inf.end_last_sequence;
                    this.out_broadcaster.push(io_obj);
                    active_sequence = 0;
                end
                continue;
            end

            if(pending_cycle) begin
                if(pending_valid) begin
                    capture_output(io_obj);
                end

                if(pending_end_sequence) begin
                    io_obj.end_last_sequence = pending_end_last_sequence;
                    this.out_broadcaster.push(io_obj);
                    active_sequence = 0;
                end
            end

            pending_cycle = 0;
            pending_valid = 0;
            pending_end_sequence = 0;
            pending_end_last_sequence = 0;

            if(active_sequence) begin
                pending_cycle = 1;
                pending_valid = !inf.idle;
                pending_end_sequence = inf.end_sequence;
                pending_end_last_sequence = inf.end_last_sequence;
            end
        end
    endtask
endclass
