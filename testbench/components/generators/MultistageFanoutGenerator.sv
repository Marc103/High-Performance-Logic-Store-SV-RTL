import utilities_pkg::*;
import constant_functions_pkg::*;

class MultistageFanoutGenerator #(type T);

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
            data_obj.data_i = $urandom(); // commonly, instead of generating random
            // MSB is implicitly used as valid signal
            data_obj.data_i[T::DATA_WIDTH - 1] = 1;
            // data, we read from some test file.
            out_broadcaster.push(data_obj);
        end
    endtask
endclass