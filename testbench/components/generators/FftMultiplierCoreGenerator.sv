import constant_functions_pkg::*;

class FftMultiplierCoreGenerator #(type T);
    typedef T::multiplier_io_t multiplier_io_t;
    typedef logic [T::DATA_WIDTH - 1 : 0] word_t;
    typedef logic [5:0][T::DATA_WIDTH - 1 : 0] bundle_t;
    `FFT_MULTIPLIER_CORE_IO_IN_STRUCT(T::DATA_WIDTH)
    `ALTERNATE_BASE_FP_MULTIPLIER_IO_IN_STRUCT(T::DATA_WIDTH)
    TriggerableQueueBroadcaster #(T) out_broadcaster;
    TriggerableQueueBroadcaster #(multiplier_io_t) source_broadcaster;
    TriggerableQueue #(multiplier_io_t) source_queue;
    AlternateBaseFpMultiplierGenerator #(multiplier_io_t) source;

    function new(TriggerableQueueBroadcaster #(T) out_broadcaster);
        this.out_broadcaster = out_broadcaster;
        source_broadcaster = new();
        source_queue = new();
        source_broadcaster.add_queue(source_queue);
        // Existing deterministic seed, canonical operand construction, and arithmetic edge cases.
        source = new(source_broadcaster);
    endfunction

    function automatic bundle_t random_bundle();
        bundle_t values;
        for(int i = 0; i < 6; i++) values[i] = source.random_operand();
        return values;
    endfunction

    task automatic add_io(ref T io_obj, input bit reset, input bit wb_valid, input bundle_t values);
        fft_multiplier_core_io_in_t transaction;
        transaction.rst_i = reset;
        transaction.w_b_valid_i = wb_valid;
        transaction.wr_i = values[0];
        transaction.wi_i = values[1];
        transaction.br_i = values[2];
        transaction.bi_i = values[3];
        transaction.ar_i = values[4];
        transaction.ai_i = values[5];
        io_obj.fft_multiplier_core_io_in_q.push_back(transaction);
        io_obj.idle.push_back(!reset && !wb_valid);
    endtask

    task automatic wait_clocks(ref T io_obj, input int count);
        for(int i = 0; i < count; i++) add_io(io_obj, 0, 0, random_bundle());
    endtask

    task automatic send_bundle(ref T io_obj, input bundle_t values,
                               input int spacing = 4, input bit early_a = 0, input int valid_clocks = 1);
        bundle_t buses;
        if(spacing < 4) $fatal(1, "Generator bundle spacing must be >=4");
        for(int i = 0; i < spacing; i++) begin
            buses = random_bundle();
            if(i == 0 || early_a) buses[3:0] = values[3:0];
            if(i == 1 || early_a) buses[5:4] = values[5:4];
            add_io(io_obj, 0, i < valid_clocks, buses);
        end
    endtask

    task automatic run();
        T io_obj;
        multiplier_io_t source_sequence;
        alternate_base_fp_multiplier_io_in_t pair_value;
        bundle_t values, buses, next_values, boundary_values;
        bit source_idle, last_source, first_source;
        int pair_index, spacing;
        // Reuse every directed and random ABFP arithmetic stimulus, not a second encoding policy.
        source.run();
        io_obj = new();
        repeat(3) add_io(io_obj, 1, 0, random_bundle());
        wait_clocks(io_obj, 2);
        // Literal four-clock cycle table, all signs, and special*canonical-zero priority.
        for(int i = 0; i < 24; i++) begin
            values = random_bundle();
            if(i % 3 == 0) begin
                values[0] = source.special_word(i[0], '1);
                values[2] = source.finite_word(i[1], '0, '0);
            end
            if(i % 5 == 0) begin
                values[1] = source.finite_word(i[0], '0, '0);
                values[3] = source.special_word(i[1], '1);
            end
            send_bundle(io_obj, values, 4, i[0]);
        end
        wait_clocks(io_obj, T::LATENCY + 2);
        // A held-high valid must not relaunch a bundle after the fourth issue.
        send_bundle(io_obj, random_bundle(), T::LATENCY + 12, 0, T::LATENCY + 12);
        wait_clocks(io_obj, 3);
        // Ignore new rising strobes during the first three issues.
        for(int offset = 1; offset <= 3; offset++) begin
            values = random_bundle();
            add_io(io_obj, 0, 1, values);
            for(int i = 1; i < T::LATENCY + 8; i++) begin
                buses = random_bundle();
                if(i == 1) buses[5:4] = values[5:4];
                add_io(io_obj, 0, i == offset, buses);
            end
            wait_clocks(io_obj, 3);
        end
        // Abort during each issue, the overlap edge, and the returning-result pipeline.
        for(int delay = 1; delay <= T::LATENCY + 2; delay++) begin
            values = random_bundle();
            next_values = random_bundle();
            add_io(io_obj, 0, 1, values);
            for(int i = 1; i < delay; i++) begin
                buses = random_bundle();
                if(i == 4) buses[3:0] = next_values[3:0];
                if(i == 1) buses[5:4] = values[5:4];
                if(i == 5) buses[5:4] = next_values[5:4];
                add_io(io_obj, 0, i == 4, buses);
            end
            repeat(2) add_io(io_obj, 1, 0, random_bundle());
            wait_clocks(io_obj, 2);
            send_bundle(io_obj, random_bundle());
            wait_clocks(io_obj, T::LATENCY + 2);
        end
        wait_clocks(io_obj, T::LATENCY + 2);
        // Deliberately put the W/B capture and following implicit A in different objects.
        boundary_values = random_bundle();
        add_io(io_obj, 0, 1, boundary_values);
        out_broadcaster.push(io_obj);

        first_source = 1;
        pair_index = 0;
        do begin
            source_queue.pop(source_sequence);
            last_source = source_sequence.end_last_sequence;
            io_obj = new();
            if(first_source) begin
                buses = random_bundle();
                buses[5:4] = boundary_values[5:4];
                add_io(io_obj, 0, 0, buses);
                wait_clocks(io_obj, 2);
                first_source = 0;
            end
            while(source_sequence.alternate_base_fp_multiplier_io_in_q.size() > 0) begin
                pair_value = source_sequence.alternate_base_fp_multiplier_io_in_q.pop_front();
                source_idle = source_sequence.idle.pop_front();
                if(source_idle) continue;
                values = random_bundle();
                // Rotate the original directed pair through every product destination.
                case(pair_index % 4)
                    0: begin values[0] = pair_value.a_i; values[2] = pair_value.b_i; end
                    1: begin values[1] = pair_value.a_i; values[3] = pair_value.b_i; end
                    2: begin values[0] = pair_value.a_i; values[3] = pair_value.b_i; end
                    3: begin values[1] = pair_value.a_i; values[2] = pair_value.b_i; end
                endcase
                if(pair_index % 29 == 0) values[4] = source.special_word(pair_index[0], '1);
                if(pair_index % 31 == 0) values[5] = source.finite_word(pair_index[0], '0, '0);
                spacing = 4;
                if(pair_index % 17 == 0) spacing += int'(source.next_random() % 8);
                send_bundle(io_obj, values, spacing, pair_index[0]);
                pair_index++;
            end
            // This also supplies an entirely idle object when RANDOM_TRANSACTIONS=0.
            wait_clocks(io_obj, T::LATENCY + 2);
            out_broadcaster.push(io_obj);
        end while(!last_source);

        io_obj = new();
        wait_clocks(io_obj, 1);
        send_bundle(io_obj, random_bundle());
        send_bundle(io_obj, random_bundle());
        wait_clocks(io_obj, T::LATENCY + 2);
        // Reset release with valid high is a fresh event because history was cleared.
        repeat(2) add_io(io_obj, 1, 1, random_bundle());
        values = random_bundle();
        add_io(io_obj, 0, 1, values);
        buses = random_bundle();
        buses[5:4] = values[5:4];
        add_io(io_obj, 0, 1, buses);
        wait_clocks(io_obj, T::LATENCY + 4);
        io_obj.end_last_sequence = 1;
        out_broadcaster.push(io_obj);
    endtask
endclass
