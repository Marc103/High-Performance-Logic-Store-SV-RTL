import constant_functions_pkg::*;

class QueueDriver #(type T, type I);

    `QUEUE_IO_IN_STRUCT(T::NUMBER_OF_QUEUES, T::DATA_WIDTH, T::ADDR_WIDTH) 

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
        queue_io_in_t queue_io_in;
        bit start_sequence = 1;

        while(io_obj.queue_io_in_q.size() > 0) begin
            
            queue_io_in = io_obj.queue_io_in_q.pop_front();

            @(posedge inf.clk_i);
            
            if(start_sequence) begin
                inf.start_sequence <= 1;
                start_sequence = 0;
            end else begin
                inf.start_sequence <= 0;
            end

            if(io_obj.queue_io_in_q.size() == 0) begin
                inf.end_sequence <= 1;
            end else begin
                inf.end_sequence <= 0;
            end

            if(io_obj.end_last_sequence) begin
                inf.end_last_sequence <= 1;
            end else begin
                inf.end_last_sequence <= 0;
            end

            if(io_obj.ignore.pop_front()) begin
                inf.rst_i       <= 0;
                inf.push_i      <= 0;
                inf.wr_data_i   <= queue_io_in.wr_data_i;
                inf.pop_i       <= 0;
                inf.less_than_i <= queue_io_in.less_than_i;
                inf.more_than_i <= queue_io_in.more_than_i;
                inf.idle        <= 1;
            end else begin
                inf.rst_i       <= queue_io_in.rst_i;
                inf.push_i      <= queue_io_in.push_i;
                inf.wr_data_i   <= queue_io_in.wr_data_i;
                inf.pop_i       <= queue_io_in.pop_i;
                inf.less_than_i <= queue_io_in.less_than_i;
                inf.more_than_i <= queue_io_in.more_than_i;
                inf.idle        <= 0;
            end

            if(io_obj.end_last_sequence) begin
                inf.end_last_sequence <= 1;
            end else begin
                inf.end_last_sequence <= 0;
            end
        end

        // back to idle (ignore)
        @(posedge inf.clk_i);
        inf.rst_i             <= 0;
        inf.push_i            <= 0;
        inf.pop_i             <= 0;
        inf.start_sequence    <= 0;
        inf.end_sequence      <= 0;
        inf.end_last_sequence <= 0;
    endtask;


    task automatic run();
        T io_obj;
        forever begin
            in_queue.pop(io_obj);
            drive(io_obj);
        end
    endtask

endclass