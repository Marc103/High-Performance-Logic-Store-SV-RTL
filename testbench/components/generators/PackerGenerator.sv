import constant_functions_pkg::*;

class PackerGenerator #(type T);
    `PACKER_IO_IN_STRUCT(T::DATA_WIDTH, T::INGRESS_SIZE)

    TriggerableQueueBroadcaster #(T) out_broadcaster;
    int seed;

    function new(TriggerableQueueBroadcaster #(T) out_broadcaster);
        this.out_broadcaster = out_broadcaster;
        this.seed = 41;
    endfunction

    function automatic logic [T::DATA_WIDTH - 1 : 0] data_from_int(input int value);
        data_from_int = '0;
        for(int bit_idx = 0; bit_idx < T::DATA_WIDTH; bit_idx++) begin
            data_from_int[bit_idx] = (((value >> bit_idx) & 1) != 0);
        end
    endfunction

    task automatic add_io(
        ref T io_obj,
        input logic idle,
        input logic [T::INGRESS_SIZE - 1 : 0][T::DATA_WIDTH - 1 : 0] unpacked,
        input logic sync
    );
        packer_io_in_t packer_io_in;

        packer_io_in.unpacked_i = unpacked;
        packer_io_in.sync_i = sync;
        io_obj.packer_io_in_q.push_back(packer_io_in);
        io_obj.idle.push_back(idle);
    endtask

    task automatic add_pattern(ref T io_obj, input logic sync);
        logic [T::INGRESS_SIZE - 1 : 0][T::DATA_WIDTH - 1 : 0] unpacked;

        for(int i = 0; i < T::INGRESS_SIZE; i++) begin
            unpacked[i] = data_from_int(seed + i);
        end
        seed += T::INGRESS_SIZE;
        add_io(io_obj, 0, unpacked, sync);
    endtask

    task automatic add_complete_group(ref T io_obj, input logic sync_first);
        for(int cycle = 0; cycle < T::STRIDE; cycle++) begin
            add_pattern(io_obj, sync_first && (cycle == 0));
        end
    endtask

    task automatic run();
        T io_obj;
        io_obj = new();

        // Establish phase, then verify the cadence continues without repeated sync pulses.
        add_complete_group(io_obj, 1);
        add_complete_group(io_obj, 0);

        if(T::STRIDE > 1) begin
            // Start a partial group, then discard it by resynchronizing.
            for(int cycle = 0; cycle < ((T::STRIDE + 1) / 2); cycle++) begin
                add_pattern(io_obj, 0);
            end
            add_complete_group(io_obj, 1);

            // Consecutive synchronization pulses must restart from the latest pulse.
            add_pattern(io_obj, 1);
            add_complete_group(io_obj, 1);
        end else begin
            add_complete_group(io_obj, 1);
            add_complete_group(io_obj, 0);
        end

        // A registered input needs one external cycle for the final group to emerge.
        if(T::REGISTERED_IN == 1) begin
            add_io(io_obj, 1, '0, 0);
        end

        io_obj.end_last_sequence = 1;
        out_broadcaster.push(io_obj);
    endtask
endclass
