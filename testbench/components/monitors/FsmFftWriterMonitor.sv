import constant_functions_pkg::*;

class FsmFftWriterMonitor #(type T, type I);
    `FSM_FFT_WRITER_IO_IN_STRUCT(T::DATA_WIDTH, T::ADDR_WIDTH)
    `FSM_FFT_WRITER_IO_OUT_STRUCT(T::DATA_WIDTH, T::ADDR_WIDTH)
    TriggerableQueueBroadcaster #(T) out_broadcaster;
    I inf;
    bit active = 0;

    function new(TriggerableQueueBroadcaster #(T) out_broadcaster, I inf);
        this.out_broadcaster = out_broadcaster;
        this.inf = inf;
    endfunction

    task automatic run();
        T io_obj;
        fsm_fft_writer_io_in_t stimulus;
        fsm_fft_writer_io_out_t transaction;
        forever begin
            @(negedge inf.clk_i);
            // Driver changes inputs one time unit later. These inputs were consumed at posedge.
            if(inf.start_sequence) begin
                if(active) $fatal(1, "Overlapping monitored sequences");
                io_obj = new();
                active = 1;
            end
            if(active) begin
                stimulus = {inf.rst_i, inf.a_wr_addr_i, inf.b_wr_addr_i, inf.valid_i, inf.y0_i, inf.y1_i};
                transaction = {inf.wr_addr_o, inf.wr_data_o, inf.wr_en_o};
                io_obj.committed_q.push_back({inf.sampled_wr_addr, inf.sampled_wr_data, inf.sampled_wr_en});
                io_obj.fsm_fft_writer_io_in_q.push_back(stimulus);
                io_obj.fsm_fft_writer_io_out_q.push_back(transaction);
                if(inf.end_sequence) begin
                    io_obj.end_last_sequence = inf.end_last_sequence;
                    out_broadcaster.push(io_obj);
                    active = 0;
                end
            end
        end
    endtask
endclass
