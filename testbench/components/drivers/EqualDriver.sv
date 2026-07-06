import constant_functions_pkg::*;

class EqualDriver #(type T, type I);
    `EQUAL_IO_IN_STRUCT(T::DATA_WIDTH)

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
        equal_io_in_t equal_io_in;
        bit start_sequence = 1;

        while(io_obj.equal_io_in_q.size() > 0) begin
            
            equal_io_in = io_obj.equal_io_in_q.pop_front();

            @(posedge inf.clk_i);

            if(start_sequence) begin
                inf.start_sequence <= 1;
                start_sequence = 0;
            end else begin
                inf.start_sequence <= 0;
            end

            if(io_obj.equal_io_in_q.size() == 0) begin
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
                inf.data_a_i <= '0;
                inf.data_b_i <= '0;
                inf.idle     <= 1;
            end else begin
                inf.data_a_i <= equal_io_in.data_a_i;
                inf.data_b_i <= equal_io_in.data_b_i;
                inf.idle     <= 0;
            end
        end

        // back to idle, nothing to do
        @(posedge inf.clk_i);
        inf.data_a_i          <= '0;
        inf.data_b_i          <= '0;
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
