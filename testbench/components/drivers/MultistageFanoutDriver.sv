import constant_functions_pkg::*;

class MultistageFanoutDriver #(type T, type I);
    ////////////////////////////////////////////////////////////////
    // Globally Defined Locally Set Parameters
    localparam STAGES            = multistage_fanout_STAGES           (T::FANOUT_FACTOR, T::FANOUT_SIZE);
    localparam FINAL_FANOUT_SIZE = multistage_fanout_FINAL_FANOUT_SIZE(T::FANOUT_FACTOR, T::STAGES);
    localparam LATENCY           = multistage_fanout_LATENCY          (T::IMMEDIATE_START_FANOUT, T::STAGES);

    `MULTISTAGE_FANOUT_IO_IN_STRUCT(T::DATA_WIDTH)

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
        multistage_fanout_io_in_t multistage_fanout_io_in;
        bit start_sequence = 1;

        while(io_obj.multistage_fanout_io_in_q.size() > 0) begin
            
            multistage_fanout_io_in = io_obj.multistage_fanout_io_in_q.pop_front();

            @(posedge inf.clk_i);

            if(start_sequence) begin
                inf.start_sequence <= 1;
                start_sequence = 0;
            end else begin
                inf.start_sequence <= 0;
            end

            if(io_obj.multistage_fanout_io_in_q.size() == 0) begin
                inf.end_sequence <= 1;
            end else begin
                inf.end_sequence <= 0;
            end

            if(io_obj.end_last_sequence) begin
                inf.end_last_sequence <= 1;
            end else begin
                inf.end_last_sequence <= 0;
            end

            if(io_obj.idle.pop_front()) begin
                inf.data_i   <= multistage_fanout_io_in.data_i;
                inf.idle     <= 1;
            end else begin
                inf.data_i   <= multistage_fanout_io_in.data_i;
                inf.idle     <= 0;
            end
        end

        // back to idle, nothing to do
        @(posedge inf.clk_i);
    endtask;

    task automatic run();
        T io_obj;
        forever begin
            in_queue.pop(io_obj);
            drive(io_obj);
        end
    endtask

endclass