import constant_functions_pkg::*;

class FsmFftWriterDriver #(type T, type I);
    `FSM_FFT_WRITER_IO_IN_STRUCT(T::DATA_WIDTH, T::ADDR_WIDTH)
    TriggerableQueue #(T) in_queue;
    I inf;

    function new(TriggerableQueue #(T) in_queue, I inf);
        this.in_queue = in_queue;
        this.inf = inf;
    endfunction

    task automatic drive(T io_obj);
        fsm_fft_writer_io_in_t transaction;
        bit first_item = 1;
        bit idle_item;
        if(io_obj.idle.size() != io_obj.fsm_fft_writer_io_in_q.size())
            $fatal(1, "Input and idle queue sizes differ");
        if(io_obj.idle.size() == 0) $fatal(1, "Empty sequence must contain at least an idle clock");
        while(io_obj.fsm_fft_writer_io_in_q.size() > 0) begin
            transaction = io_obj.fsm_fft_writer_io_in_q.pop_front();
            idle_item = io_obj.idle.pop_front();
            // Monitor samples the previous clock at negedge; drive afterwards for next posedge.
            @(negedge inf.clk_i);
            #1;
            inf.start_sequence = first_item;
            first_item = 0;
            inf.end_sequence = io_obj.fsm_fft_writer_io_in_q.size() == 0;
            inf.end_last_sequence = io_obj.end_last_sequence;
            inf.idle = idle_item;
            // Idle metadata never suppresses an input clock.
            inf.rst_i = transaction.rst_i;
            inf.a_wr_addr_i = transaction.a_wr_addr_i;
            inf.b_wr_addr_i = transaction.b_wr_addr_i;
            inf.valid_i = transaction.valid_i;
            inf.y0_i = transaction.y0_i;
            inf.y1_i = transaction.y1_i;
        end
        // No inserted clocks between objects; model and DUT see the same continuous stream.
    endtask

    task automatic run();
        T io_obj;
        forever begin
            in_queue.pop(io_obj);
            drive(io_obj);
            if(io_obj.end_last_sequence) begin
                @(negedge inf.clk_i);
                #1;
                inf.start_sequence = 0;
                inf.end_sequence = 0;
                inf.end_last_sequence = 0;
                inf.valid_i = 0;
                inf.rst_i = 0;
                inf.idle = 1;
            end
        end
    endtask
endclass
