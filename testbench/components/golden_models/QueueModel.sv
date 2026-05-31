import constant_functions_pkg::*;

class QueueModel #(type T);
    ////////////////////////////////////////////////////////////////
    // Globally Defined Locally Set Parameters
    localparam DATA_DEPTH    = queue_DATA_DEPTH    (T::ADDR_WIDTH),
    localparam READ_LATENCY  = queue_READ_LATENCY  (T::REGISTERED_IN, T::REGISTERED_IN_BRAM),
    localparam WRITE_LATENCY = queue_WRITE_LATENCY (T::REGISTERED_IN, T::REGISTERED_IN_BRAM, T::READ_THEN_WRITE)

    `QUEUE_IO_IN_STRUCT(T::NUMBER_OF_QUEUES, T::DATA_WIDTH, T::ADDR_WIDTH) 
    `QUEUE_IO_OUT_STRUCT(T::NUMBER_OF_QUEUES, T::DATA_WIDTH, T::ADDR_WIDTH) 

    TriggerableQueue #(T) in_queue;
    TriggerableQueueBroadcaster #(T) out_broadcaster;

    protected logic [T::NUMBER_OF_QUEUES : 0][T::DATA_WIDTH - 1 : 0] queue [$];
    protected logic unsigned [T::ADDR_WIDTH : 0] element_count;
    protected logic unsigned [T::ADDR_WIDTH : 0] element_max;
    protected logic [T::ADDR_WIDTH : 0] less_than;
    protected logic [T::ADDR_WIDTH : 0] more_than;
    protected logic unsigned [T::ADDR_WIDTH : 0] less_than_u;
    protected logic unsigned [T::ADDR_WIDTH : 0] more_than_u;

    protected logic unsigned [7:0] error_state;

    function new(
        TriggerableQueue #(T) in_queue,
        TriggerableQueueBroadcaster #(T) out_broadcaster
    );
        this.in_queue = in_queue;
        this.out_broadcaster = out_broadcaster;
        this.element_count = 'x;
        this.element_max = 0;
        this.element_max[T::ADDR_WIDTH] = 1'b1;
        this.less_than = 'x;
        this.more_than = 'x
        this.error_state = 0;
    endfunction

    task automatic run();
        T io_obj_in;
        T io_obj_out;
        queue_io_in_t queue_io_in;
        queue_io_out_t queue_io_out;

        forever begin
            in_queue.pop(io_obj_in);
            io_obj_out = new();

            while(io_obj_in.queue_io_in_q.size() > 0) begin
                queue_io_in = io_obj_in.queue_io_in_q.pop_front();

                if(io_obj_in.ignore.pop_front()) begin
                   continue; 
                end         

                // pop and push 
                if(queue_io_in.push && queue_io_in.pop) begin
                    this.pop_push(queue.io_obj_in.wr_data_i);
                end else

                // push
                if(queue_io_in.push && (!queue_io_in.pop)) begin
                    this.push();
                end

                // pop
                if((!queue_io_in.push) && queue_io_in.pop) begin
                    queue_io_out.rd_data_o = this.pop();

                end

                // set less than / more than
                this.set_less_than(queue_io_in.less_than_i);
                this.set_more_than(queue_io_in.more_than_i);

                // reset
                if(queue_io_in.rst_i) begin
                    this.reset();
                end 

                // populate rest of io_out
                queue_io_out.less_than_o = this.get_less_than();
                queue_io_out.more_than_o = this.get_more_than();
                queue_io_out.full_o = this.get_full();
                queue_io_out.empty_o = this.get_empty();

                io_obj_out.error_state.push_back(this.get_error_state());
                io_obj_out.queue_io_out_q.push_back(queue_io_out);
            end
            
            out_broadcaster.push(io_obj_out);
        end
    endtask

    ////////////////////////////////////////////////////////////////
    // Main Functions

    function automatic void push(logic [T::NUMBER_OF_QUEUES][T::DATA_WIDTH - 1 : 0] wr_data);
        if(element_count < element_max) begin
            this.queue.push_back(wr_data);
            this.element_count++;
        end else begin
           this.queue.push_back('x);
           this.error_state = 10; 
        end
    endfunction

    function automatic logic [T::NUMBER_OF_QUEUES][T::DATA_WIDTH - 1 : 0] pop();
        logic [T::NUMBER_OF_QUEUES][T::DATA_WIDTH - 1 : 0] rd_data;
        if(element_count > $unsigned(0)) begin
            rd_data = this.queue.pop_front()
            this.element_count--;
        end else begin
            rd_data = 'x;
            this.error_state = 20;
        end
        return rd_data;
    endfunction

    function automatic logic [T::NUMBER_OF_QUEUES][T::DATA_WIDTH - 1 : 0] pop_push();
        logic [T::NUMBER_OF_QUEUES][T::DATA_WIDTH - 1 : 0] rd_data;
        if((element_count == 0) || 
           ((element_count == $unsigned(1)) && (T::READ_THEN_WRITE == 0))) begin
            rd_data = 'x;
            this.error_state = 30;    
        end else begin
            rd_data = this.queue.pop_front();    
        end
        return rd_data;
    endfunction

    function automatic logic reset();
        this.queue.delete();
        this.element_count = 0;
    endfunction

    ////////////////////////////////////////////////////////////////
    // Set and Get Functions

    function automatic void set_less_than(logic [ADDR_WIDTH : 0] less_than);
        this.less_than   = less_than;
        this.less_than_u = this.less_than[ADDR_WIDTH : 0];
    endfunction

    function automatic logic get_less_than();
        if(error_state != 0) return 'x;
        if(this.element_count < this.less_than_u) return 1;
        return 0;
    endfunction

    function automatic void set_more_than(logic [ADDR_WIDTH : 0] more_than);
        this.more_than   = more_than
        this.more_than_u = this.more_than[ADDR_WIDTH : 0];
    endfunction

    function automatic logic get_more_than();
        if(error_state) return 'x;
        if(this.more_than_u < this.element_count) return 1;
        return 0;
    endfunction

    function automatic logic get_full();
        if(this.element_count >= this.element_max_count) return 1;
        return 0;
    endfunction

    function automatic logic get_empty();
        if(this.element_count == 0) return 1;
        return 0;
    endfunction

    function automatic logic get_error_state();
        return this.error_state;
    endfunction

endclass