import constant_functions_pkg::*;

class MultistageMuxGenerator #(type T);
    `MULTISTAGE_MUX_IO_IN_STRUCT(T::DATA_WIDTH, T::SIZE, T::SELECTOR_WIDTH)

    TriggerableQueueBroadcaster #(T) out_broadcaster;

    int seed;

    function new(TriggerableQueueBroadcaster #(T) out_broadcaster);
        this.out_broadcaster = out_broadcaster;
        seed = 17;
    endfunction

    function automatic logic [T::DATA_WIDTH - 1 : 0] data_from_int(input int value);
        data_from_int = '0;
        for(int bit_idx = 0; bit_idx < T::DATA_WIDTH; bit_idx++) begin
            data_from_int[bit_idx] = (((value >> bit_idx) & 1) != 0);
        end
    endfunction

    function automatic logic [T::SELECTOR_WIDTH - 1 : 0] sel_from_int(input int value);
        sel_from_int = '0;
        for(int bit_idx = 0; bit_idx < T::SELECTOR_WIDTH; bit_idx++) begin
            sel_from_int[bit_idx] = (((value >> bit_idx) & 1) != 0);
        end
    endfunction

    task automatic add_io(
        ref T io_obj,
        input logic idle,
        input logic [T::SIZE - 1 : 0][T::DATA_WIDTH - 1 : 0] data,
        input logic [T::SELECTOR_WIDTH - 1 : 0] sel
    );
        multistage_mux_io_in_t multistage_mux_io_in;

        multistage_mux_io_in.data_i = data;
        multistage_mux_io_in.sel_i  = sel;

        io_obj.multistage_mux_io_in_q.push_back(multistage_mux_io_in);
        io_obj.idle.push_back(idle);
    endtask

    task automatic add_seeded_io(ref T io_obj);
        logic [T::SIZE - 1 : 0][T::DATA_WIDTH - 1 : 0] data;
        logic [T::SELECTOR_WIDTH - 1 : 0] sel;

        for(int i = 0; i < T::SIZE; i++) begin
            data[i] = data_from_int(seed + (i * 13));
        end

        sel = sel_from_int(seed % T::SIZE);
        seed++;
        add_io(io_obj, 0, data, sel);
    endtask

    task automatic run();
        T io_obj;
        logic [T::SIZE - 1 : 0][T::DATA_WIDTH - 1 : 0] data;
        io_obj = new();

        for(int i = 0; i < T::SIZE; i++) begin
            data[i] = data_from_int(i);
        end

        add_io(io_obj, 0, data, '0);
        add_io(io_obj, 0, data, sel_from_int(T::SIZE - 1));

        for(int i = 0; i < T::SIZE; i++) begin
            add_io(io_obj, 0, data, sel_from_int(i));
        end

        // idle gap to verify sequence tracking
        add_io(io_obj, 1, '0, '0);

        for(int i = 0; i < 12; i++) begin
            add_seeded_io(io_obj);
        end

        // Flush any registered mux stages before ending the sequence.
        for(int i = 0; i <= T::LATENCY; i++) begin
            add_io(io_obj, 1, '0, '0);
        end

        // finished sequence.
        io_obj.end_last_sequence = 1;

        // broadcast
        out_broadcaster.push(io_obj);

    endtask
endclass
