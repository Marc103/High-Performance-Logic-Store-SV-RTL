import utilities_pkg::*;
import constant_functions_pkg::*;

class MultistageFanoutModel #(type T);

    TriggerableQueue #(T) in_queue;
    TriggerableQueueBroadcaster #(T) out_broadcaster;

    function new(
        TriggerableQueue #(T) in_queue,
        TriggerableQueueBroadcaster #(T) out_broadcaster
    );
        this.in_queue = in_queue;
        this.out_broadcaster = out_broadcaster;
    endfunction

    task automatic run();
        T data_obj;
        T model_data_obj;

        forever begin
            in_queue.pop(data_obj);

            model_data_obj = new();
            for(int i = 0; i < T::FINAL_FANOUT_SIZE; i++) begin
                model_data_obj.data_o[i] = data_obj.data_i;
                model_data_obj.data_o[i][T::DATA_WIDTH - 1] = 1;
            end
            
            out_broadcaster.push(model_data_obj);
        end
    endtask
endclass