import constant_functions_pkg::*;

class AlternateBaseFpAdderGenerator #(type T);
    `ALTERNATE_BASE_FP_ADDER_IO_IN_STRUCT(T::DATA_WIDTH)
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
        bit sign_value, int raw_exponent, logic [T::MANTISSA_WIDTH - 1 : 0] mantissa
    );
        int exponent_value;
        exponent_value = max(0, min(T::MAX_EXPONENT, raw_exponent));
        if(mantissa == '0) return {sign_value, {T::EXPONENT_WIDTH{1'b0}}, mantissa};
        if(exponent_value == T::MAX_EXPONENT) begin
            mantissa[T::MANTISSA_WIDTH - 1] = 0;
            if(T::BASE_WIDTH == 1) begin
                exponent_value = T::MAX_EXPONENT - 1;
                mantissa[T::MANTISSA_WIDTH - 1] = 1;
            end
        end
        if(exponent_value == 0) mantissa[T::MANTISSA_WIDTH - 1] = 1;
        if((mantissa >> max(0, T::MANTISSA_WIDTH - T::BASE_WIDTH)) == 0)
            mantissa[max(0, T::MANTISSA_WIDTH - T::BASE_WIDTH)] = 1;
        return {sign_value, T::EXPONENT_WIDTH'(exponent_value), mantissa};
    endfunction

    function automatic logic [T::DATA_WIDTH - 1 : 0] random_operand();
        logic [T::MANTISSA_WIDTH - 1 : 0] mantissa;
        int unsigned bits_value;
        int exponent_value;
        bit sign_value;
        bits_value = next_random();
        sign_value = bits_value[31];
        exponent_value = int'(bits_value % (T::MAX_EXPONENT + 1));
        for(int i = 0; i < T::MANTISSA_WIDTH; i++) begin
            if((i % 32) == 0) bits_value = next_random();
            mantissa[i] = bits_value[i % 32];
        end
        return finite_word(sign_value, exponent_value, mantissa);
    endfunction

    task automatic add_io(ref T io_obj, input bit idle_item,
                          input logic [T::DATA_WIDTH - 1 : 0] a, input logic [T::DATA_WIDTH - 1 : 0] b);
        alternate_base_fp_adder_io_in_t transaction;
        transaction.a_i = a;
        transaction.b_i = b;
        io_obj.alternate_base_fp_adder_io_in_q.push_back(transaction);
        io_obj.idle.push_back(idle_item);
    endtask

    task automatic run();
        T io_obj;
        logic [T::MANTISSA_WIDTH - 1 : 0] leading_min, msb_mantissa, odd_mantissa, half_mantissa;
        logic [T::DATA_WIDTH - 1 : 0] a, b, even_value, odd_value;
        int mid_exponent, max_gap, tie_gap;
        leading_min = '0;
        leading_min[max(0, T::MANTISSA_WIDTH - T::BASE_WIDTH)] = 1;
        msb_mantissa = '0;
        msb_mantissa[T::MANTISSA_WIDTH - 1] = 1;
        odd_mantissa = msb_mantissa | T::MANTISSA_WIDTH'(1);
        mid_exponent = T::MAX_EXPONENT / 2;
        even_value = finite_word(0, mid_exponent, msb_mantissa);
        odd_value = finite_word(0, mid_exponent, odd_mantissa);
        io_obj = new();
        add_io(io_obj, 0, '0, '0);
        add_io(io_obj, 0, finite_word(1, 0, '0), '0);
        add_io(io_obj, 0, even_value, '0);
        add_io(io_obj, 0, '0, even_value);
        add_io(io_obj, 0, even_value, even_value);
        add_io(io_obj, 0, even_value, finite_word(1, mid_exponent, msb_mantissa));
        add_io(io_obj, 0, finite_word(1, mid_exponent, '1), odd_value);
        add_io(io_obj, 0, finite_word(0, mid_exponent, '1), finite_word(0, mid_exponent, '1));
        add_io(io_obj, 1, '0, '0);
        // Signed zeros and exact cancellation must produce exponent zero.
        for(int signs = 0; signs < 4; signs++) begin
            add_io(io_obj, 0, finite_word(signs[0], 0, '0), finite_word(signs[1], 0, '0));
        end
        for(int exponent_value = 0; exponent_value <= T::MAX_EXPONENT; exponent_value++) begin
            a = finite_word(0, exponent_value, msb_mantissa);
            b = a;
            b[T::DATA_WIDTH - 1] = 1;
            add_io(io_obj, 0, a, b);
            add_io(io_obj, 0, b, a);
        end
        // All sign combinations, near cancellation, and shifts beyond the mantissa.
        max_gap = min(T::MAX_EXPONENT, alternate_base_fp_adder_ALIGN_CHOICES(T::BASE_WIDTH, T::MANTISSA_WIDTH) + 1);
        for(int gap = 0; gap <= max_gap; gap++) begin
            for(int signs = 0; signs < 4; signs++) begin
                a = finite_word(signs[0], T::MAX_EXPONENT, leading_min);
                b = finite_word(signs[1], T::MAX_EXPONENT - gap, '1);
                add_io(io_obj, 0, a, b);
            end
        end
        add_io(io_obj, 0, finite_word(0, T::MAX_EXPONENT, leading_min),
                         finite_word(1, max(0, T::MAX_EXPONENT - 2), T::MANTISSA_WIDTH'('h808)));
        // Exact half-ULP: even/odd ties, above half, and rounding carry.
        tie_gap = T::MANTISSA_WIDTH / T::BASE_WIDTH;
        if(tie_gap + 1 < T::MAX_EXPONENT) begin
            half_mantissa = T::MANTISSA_WIDTH'(1) << (tie_gap * T::BASE_WIDTH - 1);
            for(int sign_value = 0; sign_value < 2; sign_value++) begin
                a = finite_word(sign_value[0], tie_gap + 1, msb_mantissa);
                b = finite_word(sign_value[0], 1, half_mantissa);
                add_io(io_obj, 0, a, b);
                add_io(io_obj, 0, finite_word(sign_value[0], tie_gap + 1, odd_mantissa), b);
                add_io(io_obj, 0, a, finite_word(sign_value[0], 1, half_mantissa + T::MANTISSA_WIDTH'(1)));
                add_io(io_obj, 0, finite_word(sign_value[0], tie_gap + 1, '1), b);
            end
        end
        add_io(io_obj, 0, finite_word(0, T::MAX_EXPONENT, '1), finite_word(0, T::MAX_EXPONENT, '1));
        add_io(io_obj, 0, finite_word(1, T::MAX_EXPONENT, '1), finite_word(1, T::MAX_EXPONENT, '1));
        add_io(io_obj, 0, finite_word(0, 0, msb_mantissa), finite_word(1, 0, odd_mantissa));
        out_broadcaster.push(io_obj);

        io_obj = new();
        for(int i = 0; i < T::RANDOM_TRANSACTIONS; i++) begin
            a = random_operand();
            b = random_operand();
            if(i % 11 == 0) b = a;
            if(i % 17 == 0) begin b = a; b[T::DATA_WIDTH - 1] = ~b[T::DATA_WIDTH - 1]; end
            if(i % 23 == 0) b = '0;
            add_io(io_obj, 0, a, b);
            if(i % 13 == 12) add_io(io_obj, 1, '0, '0);
        end
        add_io(io_obj, 1, '0, '0);
        out_broadcaster.push(io_obj);

        io_obj = new();
        add_io(io_obj, 1, '0, '0);
        add_io(io_obj, 0, even_value, odd_value);
        add_io(io_obj, 1, '0, '0);
        add_io(io_obj, 0, '0, '0);
        add_io(io_obj, 1, '0, '0);
        io_obj.end_last_sequence = 1;
        out_broadcaster.push(io_obj);
    endtask
endclass
