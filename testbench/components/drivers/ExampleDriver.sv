import utilities_pkg::*;

class ExampleDriver #(type T, type I);

    TriggerableQueue #(T) in_queue;
    I inf;

    function new(
        TriggerableQueue #(T) in_queue,
        I inf
    );
        this.in_queue = in_queue;
        this.inf = inf;
    endfunction

    task automatic drive_example(T data_obj);
        inf.a_i <= data_obj.a_i;
        inf.valid_i  <= 1;
        // wait for posedge, set valid false to prevent false valids afterwards
        @(posedge inf.clk_i); 
        inf.valid_i <= 0;
    endtask;

    task automatic invalidate();
        inf.valid_i <= 0;
    endtask;

    task automatic run();
        T data_obj;
        invalidate();
        forever begin
            in_queue.pop(data_obj);
            drive_example(data_obj);
        end
    endtask

endclass