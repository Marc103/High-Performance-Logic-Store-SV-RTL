import constant_functions_pkg::*;

class QueueCarriageMonitor #(type T, type I);
    `QUEUE_CARRIAGE_IO_OUT_STRUCT(T::DATA_WIDTH)

    TriggerableQueueBroadcaster #(T) out_broadcaster;
    I inf;

    protected logic stalled = 0;
    protected logic [T::DATA_WIDTH - 1 : 0] stalled_data = '0;
    protected logic end_seen = 0;

    function new(TriggerableQueueBroadcaster #(T) out_broadcaster, I inf);
        this.out_broadcaster = out_broadcaster;
        this.inf = inf;
    endfunction

    task automatic capture_transfer(ref T io_obj);
        queue_carriage_io_out_t queue_carriage_io_out;

        queue_carriage_io_out.wr_ready_o = inf.wr_ready_o;
        queue_carriage_io_out.wr_burstready_o = inf.wr_burstready_o;
        queue_carriage_io_out.rd_data_o = inf.rd_data_o;
        queue_carriage_io_out.rd_valid_o = inf.rd_valid_o;
        queue_carriage_io_out.rd_burstvalid_o = inf.rd_burstvalid_o;
        io_obj.queue_carriage_io_out_q.push_back(queue_carriage_io_out);
    endtask

    task automatic run();
        T io_obj;
        io_obj = new();

        forever begin
            @(posedge inf.rd_clk_i);

            if(!inf.rd_rst_i) begin
                if(inf.rd_burstvalid_o && !inf.rd_valid_o) begin
                    $error("rd_burstvalid_o asserted without rd_valid_o");
                end
                if(inf.wr_burstready_o && !inf.wr_ready_o) begin
                    $error("wr_burstready_o asserted without wr_ready_o");
                end

                if(this.stalled) begin
                    if(!inf.rd_valid_o) begin
                        $error("rd_valid_o deasserted while an output item was stalled");
                    end else if(inf.rd_data_o !== this.stalled_data) begin
                        $error("rd_data_o changed while stalled, previous=%0d current=%0d",
                            this.stalled_data, inf.rd_data_o);
                    end
                end

                this.stalled = inf.rd_valid_o && !inf.rd_ready_i;
                if(this.stalled) this.stalled_data = inf.rd_data_o;

                if(inf.rd_valid_o && inf.rd_ready_i) begin
                    capture_transfer(io_obj);
                end
            end else begin
                this.stalled = 0;
            end

            if(inf.end_sequence && !this.end_seen) begin
                io_obj.end_last_sequence = inf.end_last_sequence;
                this.out_broadcaster.push(io_obj);
                io_obj = new();
                this.end_seen = 1;
            end else if(!inf.end_sequence) begin
                this.end_seen = 0;
            end
        end
    endtask
endclass
