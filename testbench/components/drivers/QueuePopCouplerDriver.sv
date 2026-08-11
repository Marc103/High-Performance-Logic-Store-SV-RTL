import constant_functions_pkg::*;

class QueuePopCouplerDriver #(type T, type I);
    `QUEUE_POP_COUPLER_IO_IN_STRUCT(T::DATA_WIDTH)

    TriggerableQueue #(T) in_queue;
    I inf;

    function new(TriggerableQueue #(T) in_queue, I inf);
        this.in_queue = in_queue;
        this.inf = inf;
    endfunction

    task automatic drive(T io_obj);
        queue_pop_coupler_io_in_t queue_pop_coupler_io_in;
        bit start_sequence = 1;

        while(io_obj.queue_pop_coupler_io_in_q.size() > 0) begin
            queue_pop_coupler_io_in = io_obj.queue_pop_coupler_io_in_q.pop_front();
            @(posedge inf.rd_clk_i);

            inf.start_sequence <= start_sequence;
            start_sequence = 0;
            inf.end_sequence <= (io_obj.queue_pop_coupler_io_in_q.size() == 0);
            inf.end_last_sequence <= io_obj.end_last_sequence;

            if(io_obj.idle.pop_front()) begin
                inf.rd_rst_i     <= 0;
                inf.empty_i      <= 1;
                inf.lookahead_i  <= 1;
                inf.rd_data_i    <= '0;
                inf.rd_valid_i   <= 0;
                inf.ready_i      <= 0;
                inf.idle         <= 1;
            end else begin
                inf.rd_rst_i     <= queue_pop_coupler_io_in.rst_i;
                inf.empty_i      <= queue_pop_coupler_io_in.empty_i;
                inf.lookahead_i  <= queue_pop_coupler_io_in.lookahead_i;
                inf.rd_data_i    <= queue_pop_coupler_io_in.rd_data_i;
                inf.rd_valid_i   <= queue_pop_coupler_io_in.rd_valid_i;
                inf.ready_i      <= queue_pop_coupler_io_in.ready_i;
                inf.idle         <= 0;
            end
        end

        @(posedge inf.rd_clk_i);
        inf.rd_rst_i          <= 0;
        inf.empty_i           <= 1;
        inf.lookahead_i       <= 1;
        inf.rd_data_i         <= '0;
        inf.rd_valid_i        <= 0;
        inf.ready_i           <= 0;
        inf.start_sequence    <= 0;
        inf.end_sequence      <= 0;
        inf.end_last_sequence <= 0;
        inf.idle              <= 1;
    endtask

    task automatic run();
        T io_obj;
        forever begin
            this.in_queue.pop(io_obj);
            drive(io_obj);
        end
    endtask
endclass
