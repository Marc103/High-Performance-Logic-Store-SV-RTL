import constant_functions_pkg::*;

class QueuePushCouplerDriver #(type T, type I);
    `QUEUE_PUSH_COUPLER_IO_IN_STRUCT(T::DATA_WIDTH)

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
        queue_push_coupler_io_in_t queue_push_coupler_io_in;
        bit start_sequence = 1;

        while(io_obj.queue_push_coupler_io_in_q.size() > 0) begin
            queue_push_coupler_io_in = io_obj.queue_push_coupler_io_in_q.pop_front();

            @(posedge inf.wr_clk_i);

            inf.start_sequence <= start_sequence;
            start_sequence = 0;
            inf.end_sequence <= (io_obj.queue_push_coupler_io_in_q.size() == 0);
            inf.end_last_sequence <= io_obj.end_last_sequence;

            if(io_obj.idle.pop_front()) begin
                inf.wr_rst_i    <= 0;
                inf.wr_data_i   <= '0;
                inf.wr_valid_i  <= 0;
                inf.full_i      <= 0;
                inf.lookahead_i <= 0;
                inf.idle        <= 1;
            end else begin
                inf.wr_rst_i    <= queue_push_coupler_io_in.rst_i;
                inf.wr_data_i   <= queue_push_coupler_io_in.wr_data_i;
                inf.wr_valid_i  <= queue_push_coupler_io_in.wr_valid_i;
                inf.full_i      <= queue_push_coupler_io_in.full_i;
                inf.lookahead_i <= queue_push_coupler_io_in.lookahead_i;
                inf.idle        <= 0;
            end
        end

        @(posedge inf.wr_clk_i);
        inf.wr_rst_i         <= 0;
        inf.wr_data_i        <= '0;
        inf.wr_valid_i       <= 0;
        inf.full_i           <= 0;
        inf.lookahead_i      <= 0;
        inf.start_sequence   <= 0;
        inf.end_sequence     <= 0;
        inf.end_last_sequence <= 0;
        inf.idle             <= 1;
    endtask

    task automatic run();
        T io_obj;
        forever begin
            in_queue.pop(io_obj);
            drive(io_obj);
        end
    endtask
endclass
