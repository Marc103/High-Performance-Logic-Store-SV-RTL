import constant_functions_pkg::*;

class PackerMonitor #(type T, type I);
    `PACKER_IO_OUT_STRUCT(T::DATA_WIDTH, T::EGRESS_SIZE)

    TriggerableQueueBroadcaster #(T) out_broadcaster;
    I inf;

    logic [T::REGISTERED_IN : 0] input_valid_l = 0;
    logic [T::REGISTERED_IN : 0] sync_l = 0;
    logic active_sequence = 0;

    function new(TriggerableQueueBroadcaster #(T) out_broadcaster, I inf);
        this.out_broadcaster = out_broadcaster;
        this.inf = inf;
    endfunction

    task automatic run();
        T io_obj;
        packer_io_out_t current_out;
        logic internal_valid;
        logic internal_sync;

        forever begin
            @(negedge inf.clk_i);

            if(inf.start_sequence) begin
                io_obj = new();
                active_sequence = 1;
            end

            for(int i = T::REGISTERED_IN; i > 0; i--) begin
                input_valid_l[i] = input_valid_l[i - 1];
                sync_l[i] = sync_l[i - 1];
            end
            input_valid_l[0] = !inf.idle;
            sync_l[0] = inf.sync_i;

            internal_valid = input_valid_l[T::REGISTERED_IN];
            internal_sync = sync_l[T::REGISTERED_IN];
            current_out.packed_o = inf.packed_o;

            if(active_sequence &&
               internal_valid &&
               (inf.packer_valid_o === 1'b1) &&
               ((T::STRIDE == 1) || !internal_sync)) begin
                io_obj.packer_io_out_q.push_back(current_out);
            end

            if(active_sequence && inf.end_sequence) begin
                if(inf.end_last_sequence) begin
                    io_obj.end_last_sequence = 1;
                end
                this.out_broadcaster.push(io_obj);
                active_sequence = 0;
            end
        end
    endtask
endclass
