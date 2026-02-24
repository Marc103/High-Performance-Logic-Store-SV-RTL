import utilities_pkg::*;

class ExampleScoreboard #(type T);
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
            
            assert (dut_data_obj.d_o == model_data_obj.d_o) begin
                $display("Assertion passed: dut:%d matches expected model:%d", dut_data_obj.d_o, model_data_obj.d_o);
            end else begin
                $error("Assertion failed: dut:%d but expected model:%d", dut_data_obj.d_o, model_data_obj.d_o);
            end

            #1000;
            if(received >= expected) $finish;
        end

    endtask
endclass