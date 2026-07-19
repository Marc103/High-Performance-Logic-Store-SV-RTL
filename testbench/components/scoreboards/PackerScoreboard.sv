import constant_functions_pkg::*;

class PackerScoreboard #(type T);
    `PACKER_IO_OUT_STRUCT(T::DATA_WIDTH, T::EGRESS_SIZE)

    TriggerableQueue #(T) in_queue_dut;
    TriggerableQueue #(T) in_queue_golden;

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
        packer_io_out_t dut_packer_io_out;
        packer_io_out_t model_packer_io_out;
        logic unsigned [7:0] model_error_state;
        int obj_iter = 0;
        int seq_iter;

        forever begin
            in_queue_golden.pop(model_io_obj);
            in_queue_dut.pop(dut_io_obj);

            assert(dut_io_obj.packer_io_out_q.size() == model_io_obj.packer_io_out_q.size())
                else $error(
                    "%d: Output sequence sizes differ, DUT: %d, Model: %d",
                    obj_iter,
                    dut_io_obj.packer_io_out_q.size(),
                    model_io_obj.packer_io_out_q.size()
                );

            seq_iter = 0;
            while(dut_io_obj.packer_io_out_q.size() > 0) begin
                dut_packer_io_out = dut_io_obj.packer_io_out_q.pop_front();
                model_packer_io_out = model_io_obj.packer_io_out_q.pop_front();
                model_error_state = model_io_obj.error_state.pop_front();

                assert(model_error_state == 0)
                    else $error("%d %d: Model error state %d", obj_iter, seq_iter, model_error_state);

                assert(dut_packer_io_out === model_packer_io_out)
                    else $error(
                        "%d %d: DUT does not match Model\nDUT: %p\nModel: %p",
                        obj_iter,
                        seq_iter,
                        dut_packer_io_out,
                        model_packer_io_out
                    );
                seq_iter++;
            end

            if(dut_io_obj.end_last_sequence) begin
                $display("Packer scoreboard passed %0d comparisons", seq_iter);
                $finish;
            end
            obj_iter++;
        end
    endtask
endclass
