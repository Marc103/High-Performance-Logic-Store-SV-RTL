import constant_functions_pkg::*;

class QueueTrainDriver #(type T, type I);
    `QUEUE_TRAIN_IO_IN_STRUCT(T::DATA_WIDTH)

    TriggerableQueue #(T) in_queue;
    I inf;

    function new(
        TriggerableQueue #(T) in_queue,
        I inf
    );
        this.in_queue = in_queue;
        this.inf = inf;
    endfunction

    task automatic drive(T io_obj);
        queue_train_io_in_t queue_train_io_in;
        bit start_sequence = 1;
        bit idle;

        while(io_obj.queue_train_io_in_q.size() > 0) begin
            queue_train_io_in = io_obj.queue_train_io_in_q.pop_front();
            idle = io_obj.idle.pop_front();

            if((!idle) && queue_train_io_in.wr_valid_i) begin
                do begin
                    @(negedge inf.wr_clk_i);
                    if(!inf.wr_ready_o) begin
                        inf.wr_valid_i <= 0;
                        inf.rd_ready_i <= queue_train_io_in.rd_ready_i;
                        inf.idle <= 1;
                    end
                end while(!inf.wr_ready_o);
            end else begin
                @(negedge inf.wr_clk_i);
            end

            inf.start_sequence <= start_sequence;
            start_sequence = 0;
            inf.end_sequence <= (io_obj.queue_train_io_in_q.size() == 0);
            inf.end_last_sequence <= io_obj.end_last_sequence;

            if(idle) begin
                inf.wr_rst_i <= 0;
                inf.rd_rst_i <= 0;
                inf.wr_data_i <= '0;
                inf.wr_valid_i <= 0;
                inf.rd_ready_i <= 0;
                inf.idle <= 1;
            end else begin
                inf.wr_rst_i <= queue_train_io_in.wr_rst_i;
                inf.rd_rst_i <= queue_train_io_in.rd_rst_i;
                inf.wr_data_i <= queue_train_io_in.wr_data_i;
                inf.wr_valid_i <= queue_train_io_in.wr_valid_i;
                inf.rd_ready_i <= queue_train_io_in.rd_ready_i;
                inf.idle <= 0;
            end
        end

        repeat(4) @(posedge inf.rd_clk_i);
        @(negedge inf.wr_clk_i);
        inf.wr_rst_i <= 0;
        inf.rd_rst_i <= 0;
        inf.wr_data_i <= '0;
        inf.wr_valid_i <= 0;
        inf.rd_ready_i <= 0;
        inf.start_sequence <= 0;
        inf.end_sequence <= 0;
        inf.end_last_sequence <= 0;
        inf.idle <= 1;
    endtask

    task automatic run();
        T io_obj;
        forever begin
            this.in_queue.pop(io_obj);
            drive(io_obj);
        end
    endtask
endclass
