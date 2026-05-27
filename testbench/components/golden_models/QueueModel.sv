import constant_functions_pkg::*; 

class QueueModel #(type T);

    ////////////////////////////////////////////////////////////////
    // Globally Defined Locally Set Parameters
    localparam DATA_DEPTH    = queue_DATA_DEPTH    (T::ADDR_WIDTH),
    localparam READ_LATENCY  = queue_READ_LATENCY  (T::REGISTERED_IN, T::REGISTERED_IN_BRAM),
    localparam WRITE_LATENCY = queue_WRITE_LATENCY (T::REGISTERED_IN, T::REGISTERED_IN_BRAM, T::READ_THEN_WRITE)

    TriggerableQueue #(T) in_queue;
    TriggerableQueueBroadcaster #(T) out_broadcaster;

    protected logic [T::NUMBER_OF_QUEUES : 0][T::DATA_WIDTH - 1 : 0] queue [$];
    protected unsigned logic [T::ADDR_WIDTH : 0] element_count;
    protected unsigned logic [T::ADDR_WIDTH : 0] element_max;
    protected logic [T::ADDR_WIDTH : 0] less_than;
    protected logic [T::ADDR_WIDTH : 0] more_than;
    protected logic [T::ADDR_WIDTH : 0] less_than_u;
    protected logic [T::ADDR_WIDTH : 0] more_than_u;

    protected logic error_state;

    function new(
        TriggerableQueue #(T) in_queue,
        TriggerableQueueBroadcaster #(T) out_broadcaster
    );
        this.in_queue = in_queue;
        this.out_broadcaster = out_broadcaster;
        this.element_count = 0;
        this.element_max = 0;
        this.element_max[T::ADDR_WIDTH] = 1'b1;
        this.less_than = 'x;
        this.more_than = 'x
        this.error_state = 0;
    endfunction

    task automatic run();
        T class_obj;

        forever begin
            in_queue.pop(class_obj);




            
            out_broadcaster.push(class_obj);
        end
    endtask

    function automatic void push(logic [T::NUMBER_OF_QUEUES][T::DATA_WIDTH - 1 : 0] wr_data);
        if(element_count < element_max) begin
            this.queue.push_back(wr_data);
            this.element_count++;
        end else begin
           this.queue.push_back('x);
           this.error_state = 1; 
        end
    endfunction

    function automatic logic [T::NUMBER_OF_QUEUES][T::DATA_WIDTH - 1 : 0] pop();
        logic [T::NUMBER_OF_QUEUES][T::DATA_WIDTH - 1 : 0] rd_data;
        if(element_count > $unsigned(0)) begin
            rd_data = this.queue.pop_front()
            this.element_count--;
        end else begin
            rd_data = 'x;
            this.error_state = 1;
        end
        return rd_data;
    endfunction

    function automatic logic [T::NUMBER_OF_QUEUES][T::DATA_WIDTH - 1 : 0] push_pop();
        logic [T::NUMBER_OF_QUEUES][T::DATA_WIDTH - 1 : 0] rd_data;
        if((element_count == 0) || 
           ((element_count == $unsigned(1)) && (T::READ_THEN_WRITE == 0))) begin
            rd_data = 'x;
            this.error_state = 1;    
        end else begin
            rd_data = this.queue.pop_front();    
        end
        return rd_data;
    endfunction

    function automatic void set_less_than(logic [ADDR_WIDTH : 0] less_than);
        this.less_than   = less_than;
        this.less_than_u = this.less_than[ADDR_WIDTH : 0];
    endfunction

    function automatic logic check_less_than();
        if(error_state) return 'x;
        if(this.element_count < this.less_than_u) return 1;
        return 0;
    endfunction

    function automatic void set_more_than(logic [ADDR_WIDTH : 0] more_than);
        this.more_than   = more_than
        this.more_than_u = this.more_than[ADDR_WIDTH : 0];
    endfunction

    function automatic logic check_more_than();
        if(error_state) return 'x;
        if(this.more_than_u < this.element_count) return 1;
        return 0;
    endfunction

    function automatic logic get_error_state();
        return this.error_state;
    endfunction

endclass