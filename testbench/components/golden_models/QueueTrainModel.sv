import constant_functions_pkg::*;

class QueueTrainModel #(type T);
    `QUEUE_TRAIN_IO_IN_STRUCT(T::DATA_WIDTH)
    `QUEUE_TRAIN_IO_OUT_STRUCT(T::DATA_WIDTH)

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
        T io_obj_in;
        T io_obj_out;
        queue_train_io_in_t queue_train_io_in;
        queue_train_io_out_t queue_train_io_out;

        forever begin
            this.in_queue.pop(io_obj_in);
            io_obj_out = new();

            while(io_obj_in.queue_train_io_in_q.size() > 0) begin
                queue_train_io_in = io_obj_in.queue_train_io_in_q.pop_front();

                if(io_obj_in.idle.pop_front()) begin
                    continue;
                end

                if((!queue_train_io_in.wr_rst_i) &&
                   (!queue_train_io_in.rd_rst_i) &&
                   queue_train_io_in.wr_valid_i) begin
                    // The driver presents each item only after wr_ready_o asserts,
                    // so every modeled valid cycle is an accepted transfer.
                    queue_train_io_out = '0;
                    queue_train_io_out.rd_data_o = queue_train_io_in.wr_data_i;
                    queue_train_io_out.rd_valid_o = 1;
                    io_obj_out.queue_train_io_out_q.push_back(queue_train_io_out);
                    io_obj_out.error_state.push_back(0);
                end
            end

            io_obj_out.end_last_sequence = io_obj_in.end_last_sequence;
            this.out_broadcaster.push(io_obj_out);
        end
    endtask
endclass
