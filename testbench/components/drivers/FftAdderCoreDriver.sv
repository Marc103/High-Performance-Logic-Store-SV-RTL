import constant_functions_pkg::*;

class FftAdderCoreDriver #(type T, type I);
    `FFT_ADDER_CORE_IO_IN_STRUCT(T::DATA_WIDTH)
    TriggerableQueue #(T) in_queue;
    I inf;

    function new(TriggerableQueue #(T) in_queue, I inf);
        this.in_queue = in_queue;
        this.inf = inf;
    endfunction

    task automatic drive(T io_obj);
        fft_adder_core_io_in_t transaction;
        bit first_item = 1;
        bit idle_item;
        if(io_obj.idle.size() != io_obj.fft_adder_core_io_in_q.size())
            $fatal(1, "Input and idle queue sizes differ");
        if(io_obj.idle.size() == 0) $fatal(1, "Empty sequence must contain at least an idle clock");
        while(io_obj.fft_adder_core_io_in_q.size() > 0) begin
            transaction = io_obj.fft_adder_core_io_in_q.pop_front();
            idle_item = io_obj.idle.pop_front();
            // Monitor samples the previous clock at negedge; drive afterwards for next posedge.
            @(negedge inf.clk_i);
            #1;
            inf.start_sequence = first_item;
            first_item = 0;
            inf.end_sequence = io_obj.fft_adder_core_io_in_q.size() == 0;
            inf.end_last_sequence = io_obj.end_last_sequence;
            inf.idle = idle_item;
            // Idle is metadata, not a clock enable: never mask late imaginary operands or returning results.
            inf.rst_i = transaction.rst_i;
            inf.valid_i = transaction.valid_i;
            inf.wrbr_i = transaction.wrbr_i;
            inf.wibi_i = transaction.wibi_i;
            inf.wrbi_i = transaction.wrbi_i;
            inf.wibr_i = transaction.wibr_i;
            inf.ar_i = transaction.ar_i;
            inf.ai_i = transaction.ai_i;
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
