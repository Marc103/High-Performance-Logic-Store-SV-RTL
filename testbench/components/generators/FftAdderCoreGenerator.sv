import constant_functions_pkg::*;

class FftAdderCoreGenerator #(type T);
    typedef T::adder_io_t adder_io_t;
    typedef logic [T::DATA_WIDTH - 1 : 0] word_t;
    // WrBr, WiBi, WrBi, WiBr, Ar, Ai, in ascending index order.
    typedef logic [5:0][T::DATA_WIDTH - 1 : 0] bundle_t;
    `FFT_ADDER_CORE_IO_IN_STRUCT(T::DATA_WIDTH)
    `ALTERNATE_BASE_FP_ADDER_IO_IN_STRUCT(T::DATA_WIDTH)
    TriggerableQueueBroadcaster #(T) out_broadcaster;
    TriggerableQueueBroadcaster #(adder_io_t) source_broadcaster;
    TriggerableQueue #(adder_io_t) source_queue;
    AlternateBaseFpAdderGenerator #(adder_io_t) source;

    function new(TriggerableQueueBroadcaster #(T) out_broadcaster);
        this.out_broadcaster = out_broadcaster;
        source_broadcaster = new();
        source_queue = new();
        source_broadcaster.add_queue(source_queue);
        source = new(source_broadcaster);
    endfunction

    function automatic bundle_t random_bundle();
        bundle_t values;
        for(int i = 0; i < 6; i++) values[i] = source.random_operand();
        return values;
    endfunction

    function automatic word_t negate(word_t value);
        value[T::DATA_WIDTH - 1] = ~value[T::DATA_WIDTH - 1];
        return value;
    endfunction

    // Present operands at their promised arrival clocks. In Questa, an early
    // imaginary read propagates X rather than valid data.
    function automatic bundle_t buses_at(bundle_t values, int age);
        bundle_t buses;
        buses = random_bundle();
        if(age == 0) begin
            buses[1:0] = values[1:0];
            buses[5:4] = values[5:4];
            buses[3:2] = 'x;
        end
        if(age == 1) begin buses[2] = values[2]; buses[3] = 'x; end
        if(age == 2) buses[3:2] = values[3:2];
        return buses;
    endfunction

    task automatic add_io(ref T io_obj, input bit reset, input bit valid, input bundle_t values);
        fft_adder_core_io_in_t transaction;
        transaction = {reset, valid, values[0], values[1], values[2], values[3], values[4], values[5]};
        io_obj.fft_adder_core_io_in_q.push_back(transaction);
        io_obj.idle.push_back(!reset && !valid);
    endtask

    task automatic wait_clocks(ref T io_obj, input int count);
        for(int i = 0; i < count; i++) add_io(io_obj, 0, 0, random_bundle());
    endtask

    task automatic send_bundle(ref T io_obj, input bundle_t values,
                               input int spacing = 4, input int valid_clocks = 1);
        if(spacing < 4) $fatal(1, "Generator spacing must be >=4");
        for(int i = 0; i < spacing; i++) add_io(io_obj, 0, i < valid_clocks, buses_at(values, i));
    endtask

    task automatic run();
        T io_obj;
        adder_io_t source_sequence;
        alternate_base_fp_adder_io_in_t pair_value;
        bundle_t values, buses, next_values, boundary_values;
        bit source_idle, last_source, first_source;
        int pair_index, spacing;
        source.run();
        io_obj = new();
        repeat(3) add_io(io_obj, 1, 0, random_bundle());
        wait_clocks(io_obj, 2);
        // Sustained four-clock throughput with overlapping transactions.
        for(int i = 0; i < 40; i++) send_bundle(io_obj, random_bundle());
        wait_clocks(io_obj, T::LATENCY + 2);
        send_bundle(io_obj, random_bundle(), T::LATENCY + 12, T::LATENCY + 12);
        wait_clocks(io_obj, 3);
        // Busy rising strobes at +2/+3; +1 tests a two-clock high level.
        for(int offset = 1; offset <= 3; offset++) begin
            values = random_bundle();
            for(int i = 0; i < T::LATENCY + 8; i++)
                add_io(io_obj, 0, i == 0 || i == offset, buses_at(values, i));
            wait_clocks(io_obj, 3);
        end
        // Reset at every issue/return offset, including overlapping second bundles.
        for(int delay = 1; delay <= T::LATENCY + 3; delay++) begin
            values = random_bundle();
            next_values = random_bundle();
            for(int i = 0; i < delay; i++) begin
                buses = i < 4 ? buses_at(values, i) : buses_at(next_values, i-4);
                add_io(io_obj, 0, i == 0 || i == 4, buses);
            end
            repeat(2) add_io(io_obj, 1, 0, random_bundle());
            wait_clocks(io_obj, 2);
            send_bundle(io_obj, random_bundle());
            wait_clocks(io_obj, T::LATENCY + 2);
        end
        wait_clocks(io_obj, T::LATENCY + 2);
        // Split acceptance and late imaginary inputs across sequence objects.
        boundary_values = random_bundle();
        add_io(io_obj, 0, 1, buses_at(boundary_values, 0));
        out_broadcaster.push(io_obj);
        first_source = 1;
        pair_index = 0;
        do begin
            source_queue.pop(source_sequence);
            last_source = source_sequence.end_last_sequence;
            io_obj = new();
            if(first_source) begin
                add_io(io_obj, 0, 0, buses_at(boundary_values, 1));
                add_io(io_obj, 0, 0, buses_at(boundary_values, 2));
                wait_clocks(io_obj, 1);
                first_source = 0;
            end
            while(source_sequence.alternate_base_fp_adder_io_in_q.size() > 0) begin
                pair_value = source_sequence.alternate_base_fp_adder_io_in_q.pop_front();
                source_idle = source_sequence.idle.pop_front();
                if(source_idle) continue;
                // Exercise every existing directed/random pair in all six additions.
                for(int path = 0; path < 6; path++) begin
                    values = '0;
                    case(path)
                        0: begin values[0] = pair_value.a_i; values[1] = negate(pair_value.b_i); end
                        1: begin values[2] = pair_value.a_i; values[3] = pair_value.b_i; end
                        2: begin values[0] = pair_value.a_i; values[4] = pair_value.b_i; end
                        3: begin values[0] = negate(pair_value.a_i); values[4] = pair_value.b_i; end
                        4: begin values[2] = pair_value.a_i; values[5] = pair_value.b_i; end
                        5: begin values[2] = negate(pair_value.a_i); values[5] = pair_value.b_i; end
                    endcase
                    spacing = 4;
                    if(pair_index % 17 == 0) spacing += int'(source.next_random() % 9);
                    send_bundle(io_obj, values, spacing);
                    pair_index++;
                end
            end
            // RANDOM_TRANSACTIONS=0 still contributes an entirely idle sequence.
            wait_clocks(io_obj, T::LATENCY + 2);
            out_broadcaster.push(io_obj);
        end while(!last_source);
        io_obj = new();
        send_bundle(io_obj, random_bundle());
        send_bundle(io_obj, random_bundle());
        wait_clocks(io_obj, T::LATENCY + 2);
        repeat(2) add_io(io_obj, 1, 1, random_bundle());
        // High valid on reset release is one fresh event, not a duplicate.
        values = random_bundle();
        for(int i = 0; i < 4; i++) add_io(io_obj, 0, i < 2, buses_at(values, i));
        wait_clocks(io_obj, T::LATENCY + 4);
        io_obj.end_last_sequence = 1;
        out_broadcaster.push(io_obj);
    endtask
endclass
