import constant_functions_pkg::*;

class PackerDriver #(type T, type I);
    `PACKER_IO_IN_STRUCT(T::DATA_WIDTH, T::INGRESS_SIZE)

    TriggerableQueue #(T) in_queue;
    I inf;

    function new(TriggerableQueue #(T) in_queue, I inf);
        this.in_queue = in_queue;
        this.inf = inf;
    endfunction

    task automatic drive(T io_obj);
        packer_io_in_t packer_io_in;
        bit start_sequence = 1;

        while(io_obj.packer_io_in_q.size() > 0) begin
            packer_io_in = io_obj.packer_io_in_q.pop_front();
            @(posedge inf.clk_i);

            inf.start_sequence <= start_sequence;
            start_sequence = 0;
            inf.end_sequence <= (io_obj.packer_io_in_q.size() == 0);
            inf.end_last_sequence <= io_obj.end_last_sequence;

            if(io_obj.idle.pop_front()) begin
                inf.unpacked_i <= '0;
                inf.sync_i <= 0;
                inf.idle <= 1;
            end else begin
                inf.unpacked_i <= packer_io_in.unpacked_i;
                inf.sync_i <= packer_io_in.sync_i;
                inf.idle <= 0;
            end
        end

        @(posedge inf.clk_i);
        inf.unpacked_i <= '0;
        inf.sync_i <= 0;
        inf.start_sequence <= 0;
        inf.end_sequence <= 0;
        inf.end_last_sequence <= 0;
        inf.idle <= 1;
    endtask

    task automatic run();
        T io_obj;
        forever begin
            in_queue.pop(io_obj);
            drive(io_obj);
        end
    endtask
endclass
