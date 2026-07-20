import constant_functions_pkg::*;

class AlignerModel #(type T);
    `ALIGNER_IO_IN_STRUCT(T::DATA_WIDTH, T::SIZE)
    `ALIGNER_IO_OUT_STRUCT(T::DATA_WIDTH, T::SIZE, T::PRIORITY_ENCODER_OUTPUT_DATA_WIDTH)

    TriggerableQueue #(T) in_queue;
    TriggerableQueueBroadcaster #(T) out_broadcaster;

    protected logic unsigned [7:0] error_state;
    protected int unsigned selected_index;

    function new(
        TriggerableQueue #(T) in_queue,
        TriggerableQueueBroadcaster #(T) out_broadcaster
    );
        this.in_queue = in_queue;
        this.out_broadcaster = out_broadcaster;
        this.error_state = 0;
        this.selected_index = 0;
    endfunction

    task automatic run();
        T io_obj_in;
        T io_obj_out;
        aligner_io_in_t current_in;
        aligner_io_in_t pending_in;
        aligner_io_out_t aligner_io_out;
        logic current_idle;
        logic pending_valid;
        logic matched;

        forever begin
            in_queue.pop(io_obj_in);
            io_obj_out = new();
            pending_valid = 0;

            while(io_obj_in.aligner_io_in_q.size() > 0) begin
                current_in = io_obj_in.aligner_io_in_q.pop_front();
                current_idle = io_obj_in.idle.pop_front();

                if(current_idle) begin
                    current_in.data_i = '0;
                end

                if(pending_valid) begin
                    matched = update_selection(pending_in);
                    aligner_io_out.aligned_o = align(pending_in.data_i, current_in.data_i, selected_index);
                    aligner_io_out.matched_o = matched;
                    aligner_io_out.selector_o = selected_index;

                    io_obj_out.error_state.push_back(this.error_state);
                    io_obj_out.aligner_io_out_q.push_back(aligner_io_out);
                end

                pending_in = current_in;
                pending_valid = !current_idle;
            end

            io_obj_out.end_last_sequence = io_obj_in.end_last_sequence;
            out_broadcaster.push(io_obj_out);
        end
    endtask

    ////////////////////////////////////////////////////////////////
    // Main Functions
    function automatic logic update_selection(input aligner_io_in_t aligner_io_in);
        logic matched;
        matched = 0;

        for(int i = 0; i < T::SIZE; i++) begin
            if(aligner_io_in.data_i[i] == aligner_io_in.start_symbol_i) begin
                this.selected_index = i;
                matched = 1;
            end
        end

        return matched;
    endfunction

    function automatic logic [T::SIZE - 1 : 0][T::DATA_WIDTH - 1 : 0] align(
        input logic [T::SIZE - 1 : 0][T::DATA_WIDTH - 1 : 0] previous_data,
        input logic [T::SIZE - 1 : 0][T::DATA_WIDTH - 1 : 0] current_data,
        input int unsigned sel
    );
        logic [T::SIZE - 1 : 0][T::DATA_WIDTH - 1 : 0] aligned;
        int source_index;

        for(int i = 0; i < T::SIZE; i++) begin
            source_index = sel + 1 + i;
            if(source_index < T::SIZE) begin
                aligned[i] = current_data[source_index];
            end else begin
                aligned[i] = previous_data[source_index - T::SIZE];
            end
        end

        return aligned;
    endfunction
endclass
