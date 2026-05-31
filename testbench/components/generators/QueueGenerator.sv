import constant_functions_pkg::*;

class QueueGenerator #(type T);
    ////////////////////////////////////////////////////////////////
    // Globally Defined Locally Set Parameters
    localparam DATA_DEPTH    = queue_DATA_DEPTH    (T::ADDR_WIDTH),
    localparam READ_LATENCY  = queue_READ_LATENCY  (T::REGISTERED_IN, T::REGISTERED_IN_BRAM),
    localparam WRITE_LATENCY = queue_WRITE_LATENCY (T::REGISTERED_IN, T::REGISTERED_IN_BRAM, T::READ_THEN_WRITE)

    `QUEUE_IO_IN_STRUCT(T::NUMBER_OF_QUEUES, T::DATA_WIDTH, T::ADDR_WIDTH) 

    TriggerableQueueBroadcaster #(T) out_broadcaster;

    function new(TriggerableQueueBroadcaster #(T) out_broadcaster);
        this.out_broadcaster = out_broadcaster;
    endfunction
    
    task automatic run();
        T io_obj;
        queue_io_in_t queue_io_in;
        int element_max;
        logic [ADDR_WIDTH:0] less_than_i; 
        logic [ADDR_WIDTH:0] more_than_i;
        

        io_obj = new();
        element_max = 2 ** T::ADDR_WIDTH;
        less_than_i = element_max / 3;
        more_than_i = (element_max * 2) / 3;

        // reset start
        queue_io_in.rst_i = 1;
        queue_io_in.push_i = 0;
        queue_io_in.wr_data_i = $urandom();
        queue_io_in.pop_i = 0;
        queue_io_in.less_than_i = less_than_i;
        queue_io_in.more_than_i = more_than_i;
        io_obj.queue_io_in_q.push_back(queue_io_in);
        io_obj.ignore.push_back(0);

        // push
        queue_io_in.rst_i = 0;
        queue_io_in.push_i = 1;
        queue_io_in.wr_data_i = $urandom();
        queue_io_in.pop_i = 0;
        queue_io_in.less_than_i = less_than_i;
        queue_io_in.more_than_i = more_than_i;
        io_obj.queue_io_in_q.push_back(queue_io_in);
        io_obj.ignore.push_back(0); 

        // pop
        queue_io_in.rst_i = 0;
        queue_io_in.push_i = 0;
        queue_io_in.wr_data_i = $urandom();
        queue_io_in.pop_i = 1;
        queue_io_in.less_than_i = less_than_i;
        queue_io_in.more_than_i = more_than_i;
        io_obj.queue_io_in_q.push_back(queue_io_in);
        io_obj.ignore.push_back(0);  

        // push
        queue_io_in.rst_i = 0;
        queue_io_in.push_i = 1;
        queue_io_in.wr_data_i = $urandom();
        queue_io_in.pop_i = 0;
        queue_io_in.less_than_i = less_than_i;
        queue_io_in.more_than_i = more_than_i;
        io_obj.queue_io_in_q.push_back(queue_io_in);
        io_obj.ignore.push_back(0);  

        // push / pop
        queue_io_in.rst_i = 0;
        queue_io_in.push_i = 1;
        queue_io_in.wr_data_i = $urandom();
        queue_io_in.pop_i = 1;
        queue_io_in.less_than_i = less_than_i;
        queue_io_in.more_than_i = more_than_i;
        io_obj.queue_io_in_q.push_back(queue_io_in);
        io_obj.ignore.push_back(0);   

        // push / pop
        queue_io_in.rst_i = 0;
        queue_io_in.push_i = 1;
        queue_io_in.wr_data_i = $urandom();
        queue_io_in.pop_i = 1;
        queue_io_in.less_than_i = less_than_i;
        queue_io_in.more_than_i = more_than_i;
        io_obj.queue_io_in_q.push_back(queue_io_in);
        io_obj.ignore.push_back(0);  

        // pop
        queue_io_in.rst_i = 0;
        queue_io_in.push_i = 1;
        queue_io_in.wr_data_i = $urandom();
        queue_io_in.pop_i = 0;
        queue_io_in.less_than_i = less_than_i;
        queue_io_in.more_than_i = more_than_i;
        io_obj.queue_io_in_q.push_back(queue_io_in);
        io_obj.ignore.push_back(0);  

        // throw in an ignore
        queue_io_in.rst_i = 0;
        queue_io_in.push_i = 1;
        queue_io_in.wr_data_i = $urandom();
        queue_io_in.pop_i = 0;
        queue_io_in.less_than_i = less_than_i;
        queue_io_in.more_than_i = more_than_i;
        io_obj.queue_io_in_q.push_back(queue_io_in);
        io_obj.ignore.push_back(1);  

        // push till full
        for(int i = 0; i < element_max; i++) begin
            queue_io_in.rst_i = 0;
            queue_io_in.push_i = 1;
            queue_io_in.wr_data_i = $urandom();
            queue_io_in.pop_i = 0;
            queue_io_in.less_than_i = less_than_i;
            queue_io_in.more_than_i = more_than_i;
            io_obj.queue_io_in_q.push_back(queue_io_in);
            io_obj.ignore.push_back(0);  
        end

        // push / pop - only if READ_THEN_WRITE enabled
        if(T::READ_THEN_WRITE == 1) begin
            queue_io_in.rst_i = 0;
            queue_io_in.push_i = 1;
            queue_io_in.wr_data_i = $urandom();
            queue_io_in.pop_i = 1;
            queue_io_in.less_than_i = less_than_i;
            queue_io_in.more_than_i = more_than_i;
            io_obj.queue_io_in_q.push_back(queue_io_in);
            io_obj.ignore.push_back(0);
            
        end 

        // push / pop - only if READ_THEN_WRITE enabled
        if(T::READ_THEN_WRITE == 1) begin
            queue_io_in.rst_i = 0;
            queue_io_in.push_i = 1;
            queue_io_in.wr_data_i = $urandom();
            queue_io_in.pop_i = 1;
            queue_io_in.less_than_i = less_than_i;
            queue_io_in.more_than_i = more_than_i;
            io_obj.queue_io_in_q.push_back(queue_io_in);
            io_obj.ignore.push_back(0);
        end  

        // pop - only if READ_THEN_WRITE disabled
        if(T::READ_THEN_WRITE == 0) begin
            queue_io_in.rst_i = 0;
            queue_io_in.push_i = 0;
            queue_io_in.wr_data_i = $urandom();
            queue_io_in.pop_i = 1;
            queue_io_in.less_than_i = less_than_i;
            queue_io_in.more_than_i = more_than_i;
            io_obj.queue_io_in_q.push_back(queue_io_in);
            io_obj.ignore.push_back(0);  
        end

        // push - only if READ_THEN_WRITE disabled
        if(T::READ_THEN_WRITE == 0) begin
            queue_io_in.rst_i = 0;
            queue_io_in.push_i = 1;
            queue_io_in.wr_data_i = $urandom();
            queue_io_in.pop_i = 0;
            queue_io_in.less_than_i = less_than_i;
            queue_io_in.more_than_i = more_than_i;
            io_obj.queue_io_in_q.push_back(queue_io_in);
            io_obj.ignore.push_back(0);  
        end

        // reset
        queue_io_in.rst_i = 1;
        queue_io_in.push_i = 0;
        queue_io_in.wr_data_i = $urandom();
        queue_io_in.pop_i = 0;
        queue_io_in.less_than_i = less_than_i;
        queue_io_in.more_than_i = more_than_i;
        io_obj.queue_io_in_q.push_back(queue_io_in);
        io_obj.ignore.push_back(0);

        // push
        queue_io_in.rst_i = 0;
        queue_io_in.push_i = 1;
        queue_io_in.wr_data_i = $urandom();
        queue_io_in.pop_i = 0;
        queue_io_in.less_than_i = less_than_i;
        queue_io_in.more_than_i = more_than_i;
        io_obj.queue_io_in_q.push_back(queue_io_in);
        io_obj.ignore.push_back(0); 

        // pop
        queue_io_in.rst_i = 0;
        queue_io_in.push_i = 0;
        queue_io_in.wr_data_i = $urandom();
        queue_io_in.pop_i = 1;
        queue_io_in.less_than_i = less_than_i;
        queue_io_in.more_than_i = more_than_i;
        io_obj.queue_io_in_q.push_back(queue_io_in);
        io_obj.ignore.push_back(0);

        // finished sequence.

        // broadcast
        out_broadcaster.push(io_obj); 
    endtask
endclass