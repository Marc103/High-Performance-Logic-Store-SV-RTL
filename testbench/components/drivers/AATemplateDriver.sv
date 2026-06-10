import constant_functions_pkg::*;

class ???Driver #(type T, type I);
    `???_IO_IN_STRUCT(???)

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
        ???_io_in_t ???_io_in;
        bit start_sequence = 1;

        while(io_obj.???_io_in_q.size() > 0) begin
            
            ???_io_in = io_obj.???_io_in_q.pop_front();

            @(posedge inf.clk_i);

            if(start_sequence) begin
                inf.start_sequence <= 1;
                start_sequence = 0;
            end else begin
                inf.start_sequence <= 0;
            end

            if(io_obj.???_io_in_q.size() == 0) begin
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
                ???
                inf.idle     <= 1;
            end else begin
                ???
                inf.idle     <= 0;
            end
        end

        // back to idle, nothing to do
        @(posedge inf.clk_i);
    endtask;
endclass
