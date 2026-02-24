import utilities_pkg::*;

class ExampleModel #(type T);
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
            model_data_obj.d_o = data_obj.a_i + 1;

            out_broadcaster.push(model_data_obj);
        end
    endtask
endclass