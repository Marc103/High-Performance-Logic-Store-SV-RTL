import constant_functions_pkg::*;

class AlternateBaseFpMultiplierDriver #(type T, type I);
    `ALTERNATE_BASE_FP_MULTIPLIER_IO_IN_STRUCT(T::DATA_WIDTH)
    TriggerableQueue #(T) in_queue;
    I inf;

    function new(TriggerableQueue #(T) in_queue, I inf);
        this.in_queue = in_queue;
        this.inf = inf;
    endfunction

    task automatic drive(T io_obj);
        alternate_base_fp_multiplier_io_in_t transaction;
        bit first_item = 1;
        bit idle_item;
        if(io_obj.idle.size() != io_obj.alternate_base_fp_multiplier_io_in_q.size())
            $fatal(1, "Input and idle queue sizes differ");
        while(io_obj.alternate_base_fp_multiplier_io_in_q.size() > 0) begin
            transaction = io_obj.alternate_base_fp_multiplier_io_in_q.pop_front();
            idle_item = io_obj.idle.pop_front();
            @(posedge inf.clk_i);
            inf.start_sequence <= first_item;
            first_item = 0;
            inf.end_sequence <= (io_obj.alternate_base_fp_multiplier_io_in_q.size() == 0);
            inf.end_last_sequence <= io_obj.end_last_sequence;
            inf.idle <= idle_item;
            inf.a_i <= idle_item ? '0 : transaction.a_i;
            inf.b_i <= idle_item ? '0 : transaction.b_i;
        end
        @(posedge inf.clk_i);
        inf.a_i <= '0;
        inf.b_i <= '0;
        inf.start_sequence <= 0;
        inf.end_sequence <= 0;
        inf.end_last_sequence <= 0;
        inf.idle <= 1;
    endtask

    task automatic run();
        T io_obj;
        forever begin
            in_queue.pop(io_obj);
            drive(io_obj);
        end
    endtask
endclass
