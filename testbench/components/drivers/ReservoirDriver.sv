import constant_functions_pkg::*;

class ReservoirDriver #(type T, type I);
    `RESERVOIR_IO_IN_STRUCT(T::DATA_WIDTH)

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
        reservoir_io_in_t reservoir_io_in;
        bit start_sequence = 1;

        while(io_obj.reservoir_io_in_q.size() > 0) begin
            reservoir_io_in = io_obj.reservoir_io_in_q.pop_front();

            @(posedge inf.clk_i);

            inf.start_sequence <= start_sequence;
            start_sequence = 0;
            inf.end_sequence <= (io_obj.reservoir_io_in_q.size() == 0);
            inf.end_last_sequence <= io_obj.end_last_sequence;

            if(io_obj.idle.pop_front()) begin
                inf.rst_i         <= 0;
                inf.fill_data_i   <= '0;
                inf.fill_valid_i  <= 0;
                inf.drain_ready_i <= 0;
                inf.idle          <= 1;
            end else begin
                inf.rst_i         <= reservoir_io_in.rst_i;
                inf.fill_data_i   <= reservoir_io_in.fill_data_i;
                inf.fill_valid_i  <= reservoir_io_in.fill_valid_i;
                inf.drain_ready_i <= reservoir_io_in.drain_ready_i;
                inf.idle          <= 0;
            end
        end

        @(posedge inf.clk_i);
        inf.rst_i             <= 0;
        inf.fill_data_i       <= '0;
        inf.fill_valid_i      <= 0;
        inf.drain_ready_i     <= 0;
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
