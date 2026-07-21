import constant_functions_pkg::*;

class AlignerGenerator #(type T);
    `ALIGNER_IO_IN_STRUCT(T::DATA_WIDTH, T::SIZE)

    TriggerableQueueBroadcaster #(T) out_broadcaster;

    int seed;

    function new(TriggerableQueueBroadcaster #(T) out_broadcaster);
        this.out_broadcaster = out_broadcaster;
        this.seed = 37;
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
        input logic [T::SIZE - 1 : 0][T::DATA_WIDTH - 1 : 0] data,
        input logic [T::DATA_WIDTH - 1 : 0] start_symbol
    );
        aligner_io_in_t aligner_io_in;

        aligner_io_in.data_i = data;
        aligner_io_in.start_symbol_i = start_symbol;

        io_obj.aligner_io_in_q.push_back(aligner_io_in);
        io_obj.idle.push_back(idle);
    endtask

    task automatic add_pattern(
        ref T io_obj,
        input int base,
        input int match_index,
        input logic [T::DATA_WIDTH - 1 : 0] start_symbol
    );
        logic [T::SIZE - 1 : 0][T::DATA_WIDTH - 1 : 0] data;

        for(int i = 0; i < T::SIZE; i++) begin
            data[i] = data_from_int(base + i + 1);
            if(data[i] == start_symbol) begin
                data[i] = data_from_int(base + T::SIZE + i + 1);
            end
        end

        if(match_index >= 0) begin
            data[match_index] = start_symbol;
        end

        add_io(io_obj, 0, data, start_symbol);
    endtask

    task automatic run();
        T io_obj;
        logic [T::SIZE - 1 : 0][T::DATA_WIDTH - 1 : 0] data;
        logic [T::DATA_WIDTH - 1 : 0] start_symbol;
        io_obj = new();

        start_symbol = data_from_int(8'hA5);

        // Start with a match so the DUT selector is initialized before any checked output.
        add_pattern(io_obj, 1, T::START_INDEX, start_symbol);
        add_pattern(io_obj, 17, -1, start_symbol);
        add_pattern(io_obj, 33, -1, start_symbol);

        // A symbol below START_INDEX must not match or replace the retained selector.
        if(T::START_INDEX > 0) begin
            add_pattern(io_obj, 41, T::START_INDEX - 1, start_symbol);
            add_pattern(io_obj, 45, -1, start_symbol);
        end

        // Exercise every rotation and verify that each new match replaces the selection.
        for(int sel = 0; sel < T::SELECTED_SIZE; sel++) begin
            add_pattern(io_obj, 49 + (sel * (T::SIZE + 3)), T::START_INDEX + sel, start_symbol);
            add_pattern(io_obj, 113 + (sel * (T::SIZE + 5)), -1, start_symbol);
        end

        // Multiple matches must select the highest matching index.
        for(int i = 0; i < T::SIZE; i++) begin
            data[i] = data_from_int(seed + i + 1);
        end
        data[T::START_INDEX] = start_symbol;
        data[T::SIZE - 1] = start_symbol;
        add_io(io_obj, 0, data, start_symbol);
        seed++;

        add_pattern(io_obj, 197, -1, start_symbol);

        // An idle cycle is still a physical zero-valued word for lookahead purposes.
        add_io(io_obj, 1, '0, start_symbol);

        // Re-establish a known selection after the idle gap.
        add_pattern(io_obj, 229, T::START_INDEX + (T::SELECTED_SIZE / 2), start_symbol);
        add_pattern(io_obj, 251, -1, start_symbol);

        // Final idle cycle supplies lookahead for the final valid transaction and flushes it.
        add_io(io_obj, 1, '0, start_symbol);

        io_obj.end_last_sequence = 1;
        out_broadcaster.push(io_obj);
    endtask
endclass
