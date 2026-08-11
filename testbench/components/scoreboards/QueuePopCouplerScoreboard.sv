import constant_functions_pkg::*;

class QueuePopCouplerScoreboard #(type T);
    `QUEUE_POP_COUPLER_IO_OUT_STRUCT(T::DATA_WIDTH, T::ADDR_WIDTH)

    TriggerableQueue #(T) in_queue_dut;
    TriggerableQueue #(T) in_queue_golden;

    int mismatch_count = 0;
    int checked_cycles = 0;

    function new(
        TriggerableQueue #(T) in_queue_dut,
        TriggerableQueue #(T) in_queue_golden
    );
        this.in_queue_dut = in_queue_dut;
        this.in_queue_golden = in_queue_golden;
    endfunction

    task automatic compare_output(
        input queue_pop_coupler_io_out_t dut_output,
        input queue_pop_coupler_io_out_t model_output
    );
        if(dut_output.pop_o !== model_output.pop_o) begin
            $error("Cycle %0d: pop_o mismatch, DUT=%b Model=%b",
                this.checked_cycles, dut_output.pop_o, model_output.pop_o);
            this.mismatch_count++;
        end
        if(dut_output.less_than_or_eq_o !== model_output.less_than_or_eq_o) begin
            $error("Cycle %0d: less_than_or_eq_o mismatch, DUT=%0d Model=%0d",
                this.checked_cycles,
                dut_output.less_than_or_eq_o,
                model_output.less_than_or_eq_o);
            this.mismatch_count++;
        end
        if(dut_output.rd_valid_o !== model_output.rd_valid_o) begin
            $error("Cycle %0d: rd_valid_o mismatch, DUT=%b Model=%b",
                this.checked_cycles, dut_output.rd_valid_o, model_output.rd_valid_o);
            this.mismatch_count++;
        end
        if(dut_output.burstvalid_o !== model_output.burstvalid_o) begin
            $error("Cycle %0d: burstvalid_o mismatch, DUT=%b Model=%b",
                this.checked_cycles, dut_output.burstvalid_o, model_output.burstvalid_o);
            this.mismatch_count++;
        end
        if(model_output.rd_valid_o && (dut_output.rd_data_o !== model_output.rd_data_o)) begin
            $error("Cycle %0d: rd_data_o mismatch, DUT=%0h Model=%0h",
                this.checked_cycles, dut_output.rd_data_o, model_output.rd_data_o);
            this.mismatch_count++;
        end
    endtask

    task automatic run();
        T dut_io_obj;
        T model_io_obj;
        queue_pop_coupler_io_out_t dut_output;
        queue_pop_coupler_io_out_t model_output;
        logic unsigned [7:0] model_error_state;

        forever begin
            this.in_queue_golden.pop(model_io_obj);
            this.in_queue_dut.pop(dut_io_obj);

            if(dut_io_obj.queue_pop_coupler_io_out_q.size() !=
               model_io_obj.queue_pop_coupler_io_out_q.size()) begin
                $error("Output sequence size mismatch, DUT=%0d Model=%0d",
                    dut_io_obj.queue_pop_coupler_io_out_q.size(),
                    model_io_obj.queue_pop_coupler_io_out_q.size());
                this.mismatch_count++;
            end

            while((dut_io_obj.queue_pop_coupler_io_out_q.size() > 0) &&
                  (model_io_obj.queue_pop_coupler_io_out_q.size() > 0)) begin
                dut_output = dut_io_obj.queue_pop_coupler_io_out_q.pop_front();
                model_output = model_io_obj.queue_pop_coupler_io_out_q.pop_front();
                model_error_state = model_io_obj.error_state.pop_front();

                if(model_error_state != 0) begin
                    $error("Cycle %0d: model error state %0d",
                        this.checked_cycles, model_error_state);
                    this.mismatch_count++;
                end

                compare_output(dut_output, model_output);
                this.checked_cycles++;
            end

            if(dut_io_obj.end_last_sequence || model_io_obj.end_last_sequence) begin
                if(dut_io_obj.end_last_sequence !== model_io_obj.end_last_sequence) begin
                    $error("DUT/model final sequence markers differ");
                    this.mismatch_count++;
                end

                if(this.mismatch_count == 0) begin
                    $display("QueuePopCoupler scoreboard passed %0d checked cycles",
                        this.checked_cycles);
                    $finish;
                end else begin
                    $fatal(1, "QueuePopCoupler scoreboard failed with %0d mismatches",
                        this.mismatch_count);
                end
            end
        end
    endtask
endclass
