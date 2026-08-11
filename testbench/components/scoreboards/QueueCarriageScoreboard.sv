import constant_functions_pkg::*;

class QueueCarriageScoreboard #(type T);
    `QUEUE_CARRIAGE_IO_OUT_STRUCT(T::DATA_WIDTH)

    TriggerableQueue #(T) in_queue_dut;
    TriggerableQueue #(T) in_queue_golden;

    int mismatch_count = 0;
    int checked_transfers = 0;

    function new(
        TriggerableQueue #(T) in_queue_dut,
        TriggerableQueue #(T) in_queue_golden
    );
        this.in_queue_dut = in_queue_dut;
        this.in_queue_golden = in_queue_golden;
    endfunction

    task automatic run();
        T dut_io_obj;
        T model_io_obj;
        queue_carriage_io_out_t dut_output;
        queue_carriage_io_out_t model_output;
        logic unsigned [7:0] model_error_state;

        forever begin
            this.in_queue_golden.pop(model_io_obj);
            this.in_queue_dut.pop(dut_io_obj);

            if(dut_io_obj.queue_carriage_io_out_q.size() !=
               model_io_obj.queue_carriage_io_out_q.size()) begin
                $display("ERROR: Transfer count mismatch, DUT=%0d Model=%0d",
                    dut_io_obj.queue_carriage_io_out_q.size(),
                    model_io_obj.queue_carriage_io_out_q.size());
                this.mismatch_count++;
            end

            while((dut_io_obj.queue_carriage_io_out_q.size() > 0) &&
                  (model_io_obj.queue_carriage_io_out_q.size() > 0)) begin
                dut_output = dut_io_obj.queue_carriage_io_out_q.pop_front();
                model_output = model_io_obj.queue_carriage_io_out_q.pop_front();
                model_error_state = model_io_obj.error_state.pop_front();

                if(model_error_state != 0) begin
                    $error("Transfer %0d: model error state %0d",
                        this.checked_transfers, model_error_state);
                    this.mismatch_count++;
                end

                if(dut_output.rd_data_o !== model_output.rd_data_o) begin
                    $error("Transfer %0d: data mismatch, DUT=%0d Model=%0d",
                        this.checked_transfers,
                        dut_output.rd_data_o,
                        model_output.rd_data_o);
                    this.mismatch_count++;
                end
                this.checked_transfers++;
            end

            if(dut_io_obj.end_last_sequence || model_io_obj.end_last_sequence) begin
                if(dut_io_obj.end_last_sequence !== model_io_obj.end_last_sequence) begin
                    $error("DUT/model final sequence markers differ");
                    this.mismatch_count++;
                end

                if(this.mismatch_count == 0) begin
                    $display("QueueCarriage scoreboard passed %0d ordered transfers",
                        this.checked_transfers);
                    $finish;
                end else begin
                    $fatal(1, "QueueCarriage scoreboard failed with %0d mismatches",
                        this.mismatch_count);
                end
            end
        end
    endtask
endclass
