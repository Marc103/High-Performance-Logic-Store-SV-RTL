import constant_functions_pkg::*;

class FftAdderCoreMonitor #(type T, type I);
    `FFT_ADDER_CORE_IO_IN_STRUCT(T::DATA_WIDTH)
    `FFT_ADDER_CORE_IO_OUT_STRUCT(T::DATA_WIDTH)
    TriggerableQueueBroadcaster #(T) out_broadcaster;
    I inf;
    bit active = 0;

    function new(TriggerableQueueBroadcaster #(T) out_broadcaster, I inf);
        this.out_broadcaster = out_broadcaster;
        this.inf = inf;
    endfunction

    task automatic run();
        T io_obj;
        fft_adder_core_io_in_t stimulus;
        fft_adder_core_io_out_t transaction;
        forever begin
            @(negedge inf.clk_i);
            // Driver changes inputs one time unit later. These inputs were consumed at posedge.
            if(inf.start_sequence) begin
                if(active) $fatal(1, "Overlapping monitored sequences");
                io_obj = new();
                active = 1;
            end
            if(active) begin
                stimulus = {inf.rst_i, inf.valid_i, inf.wrbr_i, inf.wibi_i,
                            inf.wrbi_i, inf.wibr_i, inf.ar_i, inf.ai_i};
                transaction = {inf.y0r_o, inf.y0i_o, inf.y1r_o, inf.y1i_o, inf.valid_o};
                io_obj.fft_adder_core_io_in_q.push_back(stimulus);
                io_obj.fft_adder_core_io_out_q.push_back(transaction);
                if(inf.end_sequence) begin
                    io_obj.end_last_sequence = inf.end_last_sequence;
                    out_broadcaster.push(io_obj);
                    active = 0;
                end
            end
        end
    endtask
endclass
