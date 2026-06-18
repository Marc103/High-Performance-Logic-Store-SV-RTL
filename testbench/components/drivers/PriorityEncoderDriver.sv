import constant_functions_pkg::*;

class PriorityEncoderDriver #(type T, type I);
    `PRIORITY_ENCODER_IO_IN_STRUCT(T::INPUT_DATA_WIDTH)

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
        priority_encoder_io_in_t priority_encoder_io_in;
        bit start_sequence = 1;

        while(io_obj.priority_encoder_io_in_q.size() > 0) begin
            
            priority_encoder_io_in = io_obj.priority_encoder_io_in_q.pop_front();

            @(posedge inf.clk_i);

            if(start_sequence) begin
                inf.start_sequence <= 1;
                start_sequence = 0;
            end else begin
                inf.start_sequence <= 0;
            end

            if(io_obj.priority_encoder_io_in_q.size() == 0) begin
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
                inf.priority_i <= '0;
                inf.idle       <= 1;
            end else begin
                inf.priority_i <= priority_encoder_io_in.priority_i;
                inf.idle       <= 0;
            end
        end

        // back to idle, nothing to do
        @(posedge inf.clk_i);
        inf.priority_i        <= '0;
        inf.start_sequence    <= 0;
        inf.end_sequence      <= 0;
        inf.end_last_sequence <= 0;
        inf.idle              <= 1;
    endtask

    task automatic run();
        T io_obj;
        forever begin
            in_queue.pop(io_obj);
            drive(io_obj);
        end
    endtask
endclass
