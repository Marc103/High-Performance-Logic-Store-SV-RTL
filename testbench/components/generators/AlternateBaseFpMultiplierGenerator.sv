import constant_functions_pkg::*;

class AlternateBaseFpMultiplierGenerator #(type T);
    `ALTERNATE_BASE_FP_MULTIPLIER_IO_IN_STRUCT(T::DATA_WIDTH)
    typedef logic [T::EXPONENT_WIDTH - 1 : 0] exponent_t;
    typedef logic [T::MANTISSA_WIDTH - 1 : 0] mantissa_t;
    typedef logic [T::MODEL_PRODUCT_WIDTH - 1 : 0] product_t;
    TriggerableQueueBroadcaster #(T) out_broadcaster;
    int unsigned seed;

    function new(TriggerableQueueBroadcaster #(T) out_broadcaster);
        this.out_broadcaster = out_broadcaster;
        seed = 32'h197f23a9;
    endfunction

    function automatic int unsigned next_random();
        seed = seed * 1664525 + 1013904223;
        return seed;
    endfunction

    function automatic logic [T::DATA_WIDTH - 1 : 0] finite_word(
        bit sign_value, exponent_t exponent_value, mantissa_t mantissa
    );
        if(exponent_value == '0 || mantissa == '0)
            return {sign_value, {T::EXPONENT_WIDTH{1'b0}}, {T::MANTISSA_WIDTH{1'b0}}};
        if(&exponent_value) begin
            mantissa[T::MANTISSA_WIDTH - 1] = 0;
            if(T::BASE_WIDTH == 1) begin
                exponent_value--;
                mantissa[T::MANTISSA_WIDTH - 1] = 1;
            end
        end
        if(exponent_value == '0)
            return {sign_value, {T::EXPONENT_WIDTH{1'b0}}, {T::MANTISSA_WIDTH{1'b0}}};
        if((mantissa >> max(0, T::MANTISSA_WIDTH - T::BASE_WIDTH)) == 0)
            mantissa[max(0, T::MANTISSA_WIDTH - T::BASE_WIDTH)] = 1;
        return {sign_value, exponent_value, mantissa};
    endfunction

    function automatic logic [T::DATA_WIDTH - 1 : 0] special_word(bit sign_value, mantissa_t mantissa);
        mantissa[T::MANTISSA_WIDTH - 1] = 1;
        return {sign_value, {T::EXPONENT_WIDTH{1'b1}}, mantissa};
    endfunction

    function automatic logic [T::DATA_WIDTH - 1 : 0] random_operand();
        mantissa_t mantissa;
        exponent_t exponent_value;
        int unsigned bits_value;
        bit sign_value;
        bits_value = next_random();
        sign_value = bits_value[31];
        // Fill every bit, including exponent and mantissa widths greater than 32.
        for(int i = 0; i < T::EXPONENT_WIDTH; i++) begin
            if((i % 32) == 0) bits_value = next_random();
            exponent_value[i] = bits_value[i % 32];
        end
        for(int i = 0; i < T::MANTISSA_WIDTH; i++) begin
            if((i % 32) == 0) bits_value = next_random();
            mantissa[i] = bits_value[i % 32];
        end
        return finite_word(sign_value, exponent_value, mantissa);
    endfunction

    task automatic add_io(ref T io_obj, input bit idle_item,
                          input logic [T::DATA_WIDTH - 1 : 0] a, input logic [T::DATA_WIDTH - 1 : 0] b);
        alternate_base_fp_multiplier_io_in_t transaction;
        transaction.a_i = a;
        transaction.b_i = b;
        io_obj.alternate_base_fp_multiplier_io_in_q.push_back(transaction);
        io_obj.idle.push_back(idle_item);
    endtask

    task automatic run();
        T io_obj;
        mantissa_t leading_min, msb_mantissa, mantissa_a, mantissa_b;
        exponent_t bias, max_exponent, exponent_values[7];
        logic [T::DATA_WIDTH - 1 : 0] a, b;
        product_t threshold;
        leading_min = mantissa_t'(1) << max(0, T::MANTISSA_WIDTH - T::BASE_WIDTH);
        msb_mantissa = mantissa_t'(1) << (T::MANTISSA_WIDTH - 1);
        bias = (exponent_t'(1) << (T::EXPONENT_WIDTH - 1)) - exponent_t'(1);
        max_exponent = '1;
        exponent_values[0] = '0;
        exponent_values[1] = exponent_t'(1);
        exponent_values[2] = bias;
        exponent_values[3] = bias == 0 ? bias : bias - exponent_t'(1);
        exponent_values[4] = bias + exponent_t'(1);
        exponent_values[5] = max_exponent - exponent_t'(1);
        exponent_values[6] = max_exponent;
        io_obj = new();
        // Both normalization choices, boundaries around bias, underflow, and overflow.
        foreach(exponent_values[i]) begin
            foreach(exponent_values[j]) begin
                for(int signs = 0; signs < 4; signs++) begin
                    add_io(io_obj, 0, finite_word(signs[0], exponent_values[i], leading_min),
                                     finite_word(signs[1], exponent_values[j], leading_min));
                    add_io(io_obj, 0, finite_word(signs[0], exponent_values[i], '1),
                                     finite_word(signs[1], exponent_values[j], '1));
                    add_io(io_obj, 0, finite_word(signs[0], exponent_values[i], msb_mantissa),
                                     finite_word(signs[1], exponent_values[j], leading_min));
                end
            end
            add_io(io_obj, 1, '0, '0);
        end
        // Preserve the combined class for either input, all signs, and special * signed zero.
        for(int signs = 0; signs < 4; signs++) begin
            a = special_word(signs[0], msb_mantissa);
            b = finite_word(signs[1], 0, '0);
            add_io(io_obj, 0, a, b);
            add_io(io_obj, 0, b, a);
            b = finite_word(signs[1], exponent_t'(1), leading_min);
            add_io(io_obj, 0, a, b);
            add_io(io_obj, 0, b, a);
            b = special_word(signs[1], '1);
            add_io(io_obj, 0, a, b);
            add_io(io_obj, 0, b, a);
            add_io(io_obj, 0, special_word(signs[0], '1), finite_word(signs[1], 0, '0));
        end
        // Half-ULP ties with even/odd retained LSBs and neighbors on either side.
        // This unshifted construction applies to radices >= 4 and mantissas >= 3 bits.
        if(T::BASE_WIDTH >= 2 && T::MANTISSA_WIDTH >= 3) begin
            for(int offset = 0; offset < 4; offset++) begin
                mantissa_a = msb_mantissa;
                mantissa_b = msb_mantissa + mantissa_t'(2 * offset + 1);
                for(int delta = -1; delta <= 1; delta++) begin
                    add_io(io_obj, 0, finite_word(0, bias, mantissa_a + mantissa_t'(delta)),
                                     finite_word(0, bias + exponent_t'(1), mantissa_b));
                end
            end
        end
        // Just below the normalization threshold: rounding carry can rescue exponent zero.
        threshold = product_t'(1) << (2 * T::MANTISSA_WIDTH - T::BASE_WIDTH);
        mantissa_a = leading_min + mantissa_t'(1);
        if(mantissa_a != 0) begin
            mantissa_b = mantissa_t'((threshold - product_t'(1)) / product_t'(mantissa_a));
            for(int delta = -1; delta <= 1; delta++) begin
                add_io(io_obj, 0, finite_word(0, exponent_t'(1), mantissa_a),
                                 finite_word(0, bias, mantissa_b + mantissa_t'(delta)));
                add_io(io_obj, 0, finite_word(1, bias, mantissa_a),
                                 finite_word(0, bias + exponent_t'(1), mantissa_b + mantissa_t'(delta)));
            end
        end
        out_broadcaster.push(io_obj);

        io_obj = new();
        for(int i = 0; i < T::RANDOM_TRANSACTIONS; i++) begin
            a = random_operand();
            b = random_operand();
            if(i % 11 == 0) b = a;
            if(i % 17 == 0) begin b = a; b[T::DATA_WIDTH - 1] = ~b[T::DATA_WIDTH - 1]; end
            if(i % 5 == 0) a = special_word(a[T::DATA_WIDTH - 1], a[T::MANTISSA_WIDTH - 1 : 0]);
            if(i % 7 == 0) b = special_word(b[T::DATA_WIDTH - 1], b[T::MANTISSA_WIDTH - 1 : 0]);
            if(i % 29 == 0) a[T::DATA_WIDTH - 2 : 0] = '0;
            if(i % 31 == 0) b[T::DATA_WIDTH - 2 : 0] = '0;
            add_io(io_obj, 0, a, b);
            if(i % 13 == 12) add_io(io_obj, 1, '0, '0);
        end
        // Still exercise an all-idle sequence when RANDOM_TRANSACTIONS=0.
        add_io(io_obj, 1, '0, '0);
        out_broadcaster.push(io_obj);

        io_obj = new();
        add_io(io_obj, 1, '0, '0);
        add_io(io_obj, 0, finite_word(0, bias, msb_mantissa), finite_word(1, bias, leading_min));
        add_io(io_obj, 1, '0, '0);
        add_io(io_obj, 0, finite_word(1, 0, '0), '0);
        add_io(io_obj, 1, '0, '0);
        io_obj.end_last_sequence = 1;
        out_broadcaster.push(io_obj);
    endtask
endclass
