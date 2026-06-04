import constant_functions_pkg::*;

class QueueGenerator #(type T);
    ////////////////////////////////////////////////////////////////
    // Globally Defined Locally Set Parameters
    localparam DATA_DEPTH        = queue_DATA_DEPTH                  (T::ADDR_WIDTH);
    localparam READ_LATENCY      = queue_READ_LATENCY                (T::CONFLICT_PROOF, T::REGISTERED_IN, T::REGISTERED_IN_BRAM, T::REGISTERED_OUT_BRAM);
    localparam WRITE_LATENCY     = queue_WRITE_LATENCY               (T::CONFLICT_PROOF, T::REGISTERED_IN, T::REGISTERED_IN_BRAM);
    localparam READ_LATENCY_BRAM = bram_dual_port_simple_READ_LATENCY(T::REGISTERED_IN_BRAM, T::REGISTERED_OUT_BRAM);

    `QUEUE_IO_IN_STRUCT(T::NUMBER_OF_QUEUES, T::DATA_WIDTH, T::ADDR_WIDTH) 

    TriggerableQueueBroadcaster #(T) out_broadcaster;

    int seed;

    function new(TriggerableQueueBroadcaster #(T) out_broadcaster);
        this.out_broadcaster = out_broadcaster;
        seed = 23;
        //void'($urandom(seed)); // seed the generator once
    endfunction

    task automatic add_io(
        ref T io_obj,
        input logic rst,
        input logic push,
        input logic pop,
        input logic ignore,
        input logic [T::ADDR_WIDTH:0] less_than_i,
        input logic [T::ADDR_WIDTH:0] more_than_i
    );
        queue_io_in_t queue_io_in;

        queue_io_in.rst_i       = rst;
        queue_io_in.push_i      = push;
        for(int i = 0; i < T::NUMBER_OF_QUEUES; i++) begin
            queue_io_in.wr_data_i[i] = this.seed;
            this.seed++;
        end
        queue_io_in.pop_i       = pop;
        queue_io_in.less_than_i = less_than_i;
        queue_io_in.more_than_i = more_than_i;
        io_obj.queue_io_in_q.push_back(queue_io_in);
        io_obj.ignore.push_back(ignore);
    endtask
    

    task automatic run();
        T io_obj;
        int element_max;
        logic [T::ADDR_WIDTH:0] less_than_i; 
        logic [T::ADDR_WIDTH:0] more_than_i;

        io_obj = new();
        element_max = 2 ** T::ADDR_WIDTH;
        less_than_i = element_max / 3;
        more_than_i = (element_max * 2) / 3;

        // reset start
        add_io(io_obj, 1, 0, 0, 0, less_than_i, more_than_i);

        // start of with some empty push/pop if CONFLICT_PROOF is enabled
        if (T::CONFLICT_PROOF == 1) begin
            add_io(io_obj, 0, 1, 1, 0, less_than_i, more_than_i);
        end

        if (T::CONFLICT_PROOF == 1) begin
            add_io(io_obj, 0, 1, 1, 0, less_than_i, more_than_i);
        end

        // push
        add_io(io_obj, 0, 1, 0, 0, less_than_i, more_than_i);

        // pop
        add_io(io_obj, 0, 0, 1, 0, less_than_i, more_than_i);

        // push
        add_io(io_obj, 0, 1, 0, 0, less_than_i, more_than_i);

        // push / pop
        add_io(io_obj, 0, 1, 1, 0, less_than_i, more_than_i);

        // push / pop
        add_io(io_obj, 0, 1, 1, 0, less_than_i, more_than_i);

        // pop
        add_io(io_obj, 0, 0, 1, 0, less_than_i, more_than_i);

        // throw in an ignore
        add_io(io_obj, 0, 1, 0, 1, less_than_i, more_than_i);

        // push till full
        for (int i = 0; i < element_max; i++) begin
            add_io(io_obj, 0, 1, 0, 0, less_than_i, more_than_i);
        end

        // push / pop - only if CONFLICT_PROOF enabled
        if (T::CONFLICT_PROOF == 1) begin
            add_io(io_obj, 0, 1, 1, 0, less_than_i, more_than_i);
        end

        // push / pop - only if CONFLICT_PROOF enabled
        if (T::CONFLICT_PROOF == 1) begin
            add_io(io_obj, 0, 1, 1, 0, less_than_i, more_than_i);
        end

        // pop - only if CONFLICT_PROOF disabled
        if (T::CONFLICT_PROOF == 0) begin
            add_io(io_obj, 0, 0, 1, 0, less_than_i, more_than_i);
        end

        // push - only if CONFLICT_PROOF disabled
        if (T::CONFLICT_PROOF == 0) begin
            add_io(io_obj, 0, 1, 0, 0, less_than_i, more_than_i);
        end

        // reset
        add_io(io_obj, 1, 0, 0, 0, less_than_i, more_than_i);

        // push
        add_io(io_obj, 0, 1, 0, 0, less_than_i, more_than_i);

        // pop
        add_io(io_obj, 0, 0, 1, 0, less_than_i, more_than_i);

        // finished sequence.
        io_obj.end_last_sequence = 1;

        // broadcast
        out_broadcaster.push(io_obj);
    endtask

    
endclass