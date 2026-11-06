import constant_functions_pkg::*;

class FftMultiplierCoreMonitor #(type T, type I);
    `FFT_MULTIPLIER_CORE_IO_IN_STRUCT(T::DATA_WIDTH)
    `FFT_MULTIPLIER_CORE_IO_OUT_STRUCT(T::DATA_WIDTH)
    TriggerableQueueBroadcaster #(T) out_broadcaster;
    I inf;
    bit active = 0;

    function new(TriggerableQueueBroadcaster #(T) out_broadcaster, I inf);
        this.out_broadcaster = out_broadcaster;
        this.inf = inf;
    endfunction

    task automatic run();
        T io_obj;
        fft_multiplier_core_io_in_t stimulus;
        fft_multiplier_core_io_out_t transaction;
        forever begin
            @(negedge inf.clk_i);
            // Driver changes inputs one time unit later. These inputs were consumed at posedge.
            if(inf.start_sequence) begin
                if(active) $fatal(1, "Overlapping monitored sequences");
                io_obj = new();
                active = 1;
            end
            if(active) begin
                stimulus = {inf.rst_i, inf.w_b_valid_i, inf.wr_i, inf.wi_i,
                            inf.br_i, inf.bi_i, inf.ar_i, inf.ai_i};
                transaction = {inf.wrbr_o, inf.wibi_o, inf.wrbi_o, inf.wibr_o,
                               inf.ar_o, inf.ai_o, inf.valid_o};
                io_obj.fft_multiplier_core_io_in_q.push_back(stimulus);
                io_obj.fft_multiplier_core_io_out_q.push_back(transaction);
                if(inf.end_sequence) begin
                    io_obj.end_last_sequence = inf.end_last_sequence;
                    out_broadcaster.push(io_obj);
                    active = 0;
                end
            end
        end
    endtask
endclass
