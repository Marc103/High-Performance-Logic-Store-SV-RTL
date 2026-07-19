import constant_functions_pkg::*;

class PackerModel #(type T);
    `PACKER_IO_IN_STRUCT(T::DATA_WIDTH, T::INGRESS_SIZE)
    `PACKER_IO_OUT_STRUCT(T::DATA_WIDTH, T::EGRESS_SIZE)

    TriggerableQueue #(T) in_queue;
    TriggerableQueueBroadcaster #(T) out_broadcaster;

    protected logic unsigned [7:0] error_state;
    protected logic [T::STRIDE - 1 : 0][T::INGRESS_SIZE - 1 : 0][T::DATA_WIDTH - 1 : 0] chunks;
    protected int unsigned chunk_count;

    function new(
        TriggerableQueue #(T) in_queue,
        TriggerableQueueBroadcaster #(T) out_broadcaster
    );
        this.in_queue = in_queue;
        this.out_broadcaster = out_broadcaster;
        this.error_state = 0;
        this.chunk_count = 0;
        this.chunks = '0;
    endfunction

    task automatic run();
        T io_obj_in;
        T io_obj_out;
        packer_io_in_t packer_io_in;
        packer_io_out_t packer_io_out;

        forever begin
            in_queue.pop(io_obj_in);
            io_obj_out = new();

            while(io_obj_in.packer_io_in_q.size() > 0) begin
                packer_io_in = io_obj_in.packer_io_in_q.pop_front();

                if(io_obj_in.idle.pop_front()) begin
                    continue;
                end

                if(packer_io_in.sync_i) begin
                    this.chunk_count = 0;
                end

                this.chunks[this.chunk_count] = packer_io_in.unpacked_i;

                if(this.chunk_count == (T::STRIDE - 1)) begin
                    packer_io_out.packed_o = pack_chunks();
                    io_obj_out.error_state.push_back(this.error_state);
                    io_obj_out.packer_io_out_q.push_back(packer_io_out);
                    this.chunk_count = 0;
                end else begin
                    this.chunk_count++;
                end
            end

            io_obj_out.end_last_sequence = io_obj_in.end_last_sequence;
            out_broadcaster.push(io_obj_out);
        end
    endtask

    function automatic logic [T::EGRESS_SIZE - 1 : 0][T::DATA_WIDTH - 1 : 0] pack_chunks();
        logic [T::EGRESS_SIZE - 1 : 0][T::DATA_WIDTH - 1 : 0] packed_data;

        for(int s = 0; s < T::STRIDE; s++) begin
            for(int i = 0; i < T::INGRESS_SIZE; i++) begin
                packed_data[(s * T::INGRESS_SIZE) + i] = this.chunks[T::STRIDE - 1 - s][i];
            end
        end
        return packed_data;
    endfunction
endclass
