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
            
            if(dut_data_obj.data_o == model_data_obj.data_o) begin
                $display("Assertion passed: dut:%p matches expected model:%p", dut_data_obj.data_o, model_data_obj.data_o);
            end else begin
                $error("Assertion failed: dut:%p but expected model:%b", dut_data_obj.data_o, model_data_obj.data_o);
            end

            #1000;
            if(received >= expected) $finish;
        end

    endtask
endclass