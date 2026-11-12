import constant_functions_pkg::*;

class FsmFftReaderMonitor #(type T, type I);
    `FSM_FFT_READER_IO_IN_STRUCT(T::SAMPLES_ADDR_WIDTH)
    `FSM_FFT_READER_IO_OUT_STRUCT(T::SAMPLES_ADDR_WIDTH, T::TWIDDLES_ADDR_WIDTH)
    TriggerableQueueBroadcaster #(T) out_broadcaster;
    I inf;
    bit active = 0;

    function new(TriggerableQueueBroadcaster #(T) out_broadcaster, I inf);
        this.out_broadcaster = out_broadcaster;
        this.inf = inf;
    endfunction

    task automatic run();
        T io_obj;
        fsm_fft_reader_io_in_t stimulus;
        fsm_fft_reader_io_out_t transaction;
        forever begin
            @(negedge inf.clk_i);
            // Driver changes inputs one time unit later. These inputs were consumed at posedge.
            if(inf.start_sequence) begin
                if(active) $fatal(1, "Overlapping monitored sequences");
                io_obj = new();
                active = 1;
            end
            if(active) begin
                stimulus = {inf.rst_i, inf.fft_point_size_i, inf.fft_whole_iterations_i, inf.go_i};
                transaction = {inf.a_b_rd_addr_o, inf.a_b_rd_en_o, inf.a_valid_o, inf.b_valid_o,
                               inf.w_rd_addr_o, inf.w_rd_en_o, inf.w_valid_o, inf.busy_o, inf.fft_done_o};
                io_obj.fsm_fft_reader_io_in_q.push_back(stimulus);
                io_obj.fsm_fft_reader_io_out_q.push_back(transaction);
                if(inf.end_sequence) begin
                    io_obj.end_last_sequence = inf.end_last_sequence;
                    out_broadcaster.push(io_obj);
                    active = 0;
                end
            end
        end
    endtask
endclass
