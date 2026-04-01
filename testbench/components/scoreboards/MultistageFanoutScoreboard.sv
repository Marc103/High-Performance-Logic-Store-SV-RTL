import utilities_pkg::*;
import constant_functions_pkg::*;

class MultistageFanoutScoreboard #(type T);
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
        T dut_data_obj;
        T model_data_obj;

        // Need some kind of termination condition for the simulation
        // this doesn't necessarily need to happen here but it is the simplest.
        int received = 0;
        int expected = 10;

        forever begin
            in_queue_dut.pop(dut_data_obj);
            in_queue_golden.pop(model_data_obj);
            received++;
            
            for(int i = 0; i < T::FINAL_FANOUT_SIZE; i++) begin
                $display("iteration %d", i);
                if(dut_data_obj.data_o[i][T::DATA_WIDTH - 1 : 0] == model_data_obj.data_o[i][T::DATA_WIDTH - 1 : 0]) begin
                    $display("Assertion passed: dut:%b matches expected model:%b", dut_data_obj.data_o[i][T::DATA_WIDTH-1:0], model_data_obj.data_o[i][T::DATA_WIDTH-1:0]);
                end else begin
                    $error("Assertion failed: dut:%b but expected model:%b", dut_data_obj.data_o[i][T::DATA_WIDTH-1:0], model_data_obj.data_o[i][T::DATA_WIDTH-1:0]);
                end
            end

            #1000;
            if(received >= expected) $finish;
        end

    endtask
endclass