import utilities_pkg::*;

class MultistageFanoutMonitor #(type T, type I);
    TriggerableQueueBroadcaster #(T) out_broadcaster;
    I inf;

    function new(TriggerableQueueBroadcaster #(T) out_broadcaster,
                 I inf);
        this.out_broadcaster = out_broadcaster;
        this.inf = inf;
    endfunction

    task automatic run();
        T dut_data_obj;
        logic valid;
        forever begin
            /*
             * The convention I follow is to push data on posedge and to read data on negedge. Attempting
             * to both read/write on posedge is non-deterministic since the events are on the same delta cycle
             * and so are randomly ordered. Another solution is to wait a delta cycle via #1, but this is sort
             * annoying unless you want to actually simulate logic delay with delta cycles aswell, but then you would
             * have to keep track of when (i.e after #1 or #4?) you read anyway and adjust accordingly.
             */
            @(negedge inf.clk_i);
            
            if(inf.valid_o[0]) begin // valid o is an array, all values should become 1
                dut_data_obj = new();
                valid = 0;
                for(int i = 0; i < dut_data_obj.final_fanout_size; i++) begin
                    valid = inf.valid_o[i] | valid;
                end
                if(valid) begin
                    dut_data_obj.data_o = inf.data_o;
                    out_broadcaster.push(dut_data_obj);
                end
            end
        end
    endtask
endclass