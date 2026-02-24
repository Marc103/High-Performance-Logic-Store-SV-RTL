import utilities_pkg::*;

class ExampleMonitor #(type T, type I);
    TriggerableQueueBroadcaster #(T) out_broadcaster;
    I inf;

    function new(TriggerableQueueBroadcaster #(T) out_broadcaster,
                 I inf);
        this.out_broadcaster = out_broadcaster;
        this.inf = inf;
    endfunction

    task automatic run();
        T dut_data_obj;
        forever begin
            /*
             * The convention I follow is to push data on posedge and to read data on negedge. Attempting
             * to both read/write on posedge is non-deterministic since the events are on the same delta cycle
             * and so are randomly ordered. Another solution is to wait a delta cycle via #1, but this is sort
             * annoying unless you want to actually simulate logic delay with delta cycles aswell, but then you would
             * have to keep track of when (i.e after #1 or #4?) you read anyway and adjust accordingly.
             */
            @(negedge inf.clk_i);
            if(inf.valid_o) begin
                dut_data_obj = new();
                dut_data_obj.d_o = inf.d_o;
                out_broadcaster.push(dut_data_obj);
            end
        end
    endtask
endclass