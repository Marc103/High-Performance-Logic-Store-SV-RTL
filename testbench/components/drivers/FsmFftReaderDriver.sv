import constant_functions_pkg::*;

class FsmFftReaderDriver #(type T, type I);
    `FSM_FFT_READER_IO_IN_STRUCT(T::SAMPLES_ADDR_WIDTH)
    TriggerableQueue #(T) in_queue;
    I inf;

    function new(TriggerableQueue #(T) in_queue, I inf);
        this.in_queue = in_queue;
        this.inf = inf;
    endfunction

    task automatic drive(T io_obj);
        fsm_fft_reader_io_in_t transaction;
        bit first_item = 1;
        bit idle_item;
        if(io_obj.idle.size() != io_obj.fsm_fft_reader_io_in_q.size())
            $fatal(1, "Input and idle queue sizes differ");
        if(io_obj.idle.size() == 0) $fatal(1, "Empty sequence must contain at least an idle clock");
        while(io_obj.fsm_fft_reader_io_in_q.size() > 0) begin
            transaction = io_obj.fsm_fft_reader_io_in_q.pop_front();
            idle_item = io_obj.idle.pop_front();
            // Monitor samples the previous clock at negedge; drive afterwards for next posedge.
            @(negedge inf.clk_i);
            #1;
            inf.start_sequence = first_item;
            first_item = 0;
            inf.end_sequence = io_obj.fsm_fft_reader_io_in_q.size() == 0;
            inf.end_last_sequence = io_obj.end_last_sequence;
            inf.idle = idle_item;
            // Idle is metadata; never skip clocks with go low.
            inf.rst_i = transaction.rst_i;
            inf.fft_point_size_i = transaction.fft_point_size_i;
            inf.fft_whole_iterations_i = transaction.fft_whole_iterations_i;
            inf.go_i = transaction.go_i;
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
                inf.go_i = 0;
                inf.rst_i = 0;
                inf.idle = 1;
            end
        end
    endtask
endclass
