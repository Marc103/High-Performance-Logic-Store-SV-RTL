import utilities_pkg::*;
import constant_functions_pkg::*;

class MultistageFanoutDriver #(type T, type I);

    TriggerableQueue #(T) in_queue;
    I inf;

    function new(
        TriggerableQueue #(T) in_queue,
        I inf
    );
        this.in_queue = in_queue;
        this.inf = inf;
    endfunction

    task automatic drive(T data_obj);
        if(T::DATA_WIDTH > 1) begin
            inf.data_i  <= data_obj.data_i;
        end
        // MSB is implicitly used as valid signal
        inf.data_i[T::DATA_WIDTH-1] <= 1;

        // wait for posedge, set valid false to prevent false valids afterwards
        // (purposefully blocking assignment)
        @(posedge inf.clk_i);
        inf.data_i[T::DATA_WIDTH-1] = 0;
    endtask;

    task automatic invalidate();
        inf.data_i[T::DATA_WIDTH-1] <= 0;
    endtask;

    task automatic run();
        T data_obj;
        invalidate();
        forever begin
            in_queue.pop(data_obj);
            drive(data_obj);
        end
    endtask

endclass