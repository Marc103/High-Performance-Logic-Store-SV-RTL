import constant_functions_pkg::*;

class ReservoirNoBackpressureMonitor #(type T, type I);
    `RESERVOIR_NO_BACKPRESSURE_IO_OUT_STRUCT(T::DATA_WIDTH)

    TriggerableQueueBroadcaster #(T) out_broadcaster;
    I inf;

    function new(TriggerableQueueBroadcaster #(T) out_broadcaster,
                 I inf);
        this.out_broadcaster = out_broadcaster;
        this.inf = inf;
    endfunction

    logic active_sequence = 0;
    logic pending_cycle = 0;
    logic pending_valid = 0;
    logic pending_end_sequence = 0;
    logic pending_end_last_sequence = 0;

    task automatic run();
        T io_obj;
        reservoir_no_backpressure_io_out_t reservoir_no_backpressure_io_out;

        forever begin
            @(negedge inf.clk_i);

            if(inf.start_sequence) begin
                io_obj = new();
                active_sequence = 1;
            end

            // Inputs driven on the previous posedge update reservoir state on the
            // next posedge, so their resulting status is observed one cycle later.
            if(pending_cycle) begin
                if(pending_valid) begin
                    reservoir_no_backpressure_io_out.fill_ready_o = inf.fill_ready_o;
                    reservoir_no_backpressure_io_out.fill_burstready_o = inf.fill_burstready_o;
                    reservoir_no_backpressure_io_out.drain_data_o = inf.drain_data_o;
                    reservoir_no_backpressure_io_out.drain_valid_o = inf.drain_valid_o;
                    reservoir_no_backpressure_io_out.drain_burstmark_o = inf.drain_burstmark_o;
                    io_obj.reservoir_no_backpressure_io_out_q.push_back(
                        reservoir_no_backpressure_io_out);
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
