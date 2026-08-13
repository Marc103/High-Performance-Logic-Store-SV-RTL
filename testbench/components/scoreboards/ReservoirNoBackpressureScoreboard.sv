import constant_functions_pkg::*;

class ReservoirNoBackpressureScoreboard #(type T);
    `RESERVOIR_NO_BACKPRESSURE_IO_OUT_STRUCT(T::DATA_WIDTH)

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
        input reservoir_no_backpressure_io_out_t dut_output,
        input reservoir_no_backpressure_io_out_t model_output,
        input int cycle_index
    );
        if(dut_output.fill_ready_o !== model_output.fill_ready_o) begin
            $error("Cycle %0d: fill_ready_o mismatch, DUT=%b Model=%b",
                cycle_index, dut_output.fill_ready_o, model_output.fill_ready_o);
            this.mismatch_count++;
        end
        if(dut_output.fill_burstready_o !== model_output.fill_burstready_o) begin
            $error("Cycle %0d: fill_burstready_o mismatch, DUT=%b Model=%b",
                cycle_index,
                dut_output.fill_burstready_o,
                model_output.fill_burstready_o);
            this.mismatch_count++;
        end
        if(dut_output.drain_valid_o !== model_output.drain_valid_o) begin
            $error("Cycle %0d: drain_valid_o mismatch, DUT=%b Model=%b",
                cycle_index, dut_output.drain_valid_o, model_output.drain_valid_o);
            this.mismatch_count++;
        end
        if(dut_output.drain_burstmark_o !== model_output.drain_burstmark_o) begin
            $error("Cycle %0d: drain_burstmark_o mismatch, DUT=%b Model=%b",
                cycle_index,
                dut_output.drain_burstmark_o,
                model_output.drain_burstmark_o);
            this.mismatch_count++;
        end
        if(model_output.drain_valid_o &&
           (dut_output.drain_data_o !== model_output.drain_data_o)) begin
            $error("Cycle %0d: drain_data_o mismatch, DUT=%0d Model=%0d",
                cycle_index, dut_output.drain_data_o, model_output.drain_data_o);
            this.mismatch_count++;
        end
    endtask

    task automatic run();
        T dut_io_obj;
        T model_io_obj;
        reservoir_no_backpressure_io_out_t dut_reservoir_no_backpressure_io_out;
        reservoir_no_backpressure_io_out_t model_reservoir_no_backpressure_io_out;
        logic unsigned [7:0] model_error_state;

        forever begin
            in_queue_golden.pop(model_io_obj);
            in_queue_dut.pop(dut_io_obj);

            if(dut_io_obj.reservoir_no_backpressure_io_out_q.size() !=
               model_io_obj.reservoir_no_backpressure_io_out_q.size()) begin
                $error("Output sequence size mismatch, DUT=%0d Model=%0d",
                    dut_io_obj.reservoir_no_backpressure_io_out_q.size(),
                    model_io_obj.reservoir_no_backpressure_io_out_q.size());
                this.mismatch_count++;
            end

            while((dut_io_obj.reservoir_no_backpressure_io_out_q.size() > 0) &&
                  (model_io_obj.reservoir_no_backpressure_io_out_q.size() > 0)) begin
                dut_reservoir_no_backpressure_io_out = dut_io_obj.reservoir_no_backpressure_io_out_q.pop_front();
                model_reservoir_no_backpressure_io_out = model_io_obj.reservoir_no_backpressure_io_out_q.pop_front();
                model_error_state = model_io_obj.error_state.pop_front();

                if(model_error_state != 0) begin
                    $error("Cycle %0d: model error state %0d",
                        this.checked_cycles, model_error_state);
                    this.mismatch_count++;
                end

                compare_output(dut_reservoir_no_backpressure_io_out,
                    model_reservoir_no_backpressure_io_out,
                    this.checked_cycles);
                this.checked_cycles++;
            end

            if(dut_io_obj.end_last_sequence || model_io_obj.end_last_sequence) begin
                if(dut_io_obj.end_last_sequence !== model_io_obj.end_last_sequence) begin
                    $error("DUT/model final sequence markers differ");
                    this.mismatch_count++;
                end

                if(this.mismatch_count == 0) begin
                    $display("Reservoir no-backpressure scoreboard passed %0d checked cycles",
                        this.checked_cycles);
                    $finish;
                end else begin
                    $fatal(1, "Reservoir no-backpressure scoreboard failed with %0d mismatches",
                        this.mismatch_count);
                end
            end
        end
    endtask
endclass
