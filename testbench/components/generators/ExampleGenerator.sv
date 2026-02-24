import utilities_pkg::*;

class ExampleGenerator #(type T);
    TriggerableQueueBroadcaster #(T) out_broadcaster;

    function new(TriggerableQueueBroadcaster #(T) out_broadcaster);
        this.out_broadcaster = out_broadcaster;
    endfunction
    
    task automatic run();
        T data_obj;
        /*
         * Although one could have a forever loop just generating a bunch of test data and rely
         * on simulation termination condition elsewhere (for example, in the scoreboard),
         * it's better to generate a set number of test items so as not to overburden the system.
         */

        for(int i = 0; i < 10; i++) begin
            data_obj = new();
            data_obj.a_i = $urandom(); // commonly, instead of generating random
            // data, we read from some test file.
            out_broadcaster.push(data_obj);
        end
    endtask
endclass