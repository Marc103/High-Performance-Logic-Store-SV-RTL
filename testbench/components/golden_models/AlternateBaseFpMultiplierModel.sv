import constant_functions_pkg::*;

class AlternateBaseFpMultiplierModel #(type T);
    `ALTERNATE_BASE_FP_MULTIPLIER_IO_IN_STRUCT(T::DATA_WIDTH)
    `ALTERNATE_BASE_FP_MULTIPLIER_IO_OUT_STRUCT(T::DATA_WIDTH)
    // Exact integer product and remainder; no host floating-point arithmetic.
    typedef logic [T::MODEL_PRODUCT_WIDTH - 1 : 0] product_t;
    typedef logic signed [T::MODEL_EXPONENT_WIDTH - 1 : 0] exponent_t;
    TriggerableQueue #(T) in_queue;
    TriggerableQueueBroadcaster #(T) out_broadcaster;
    protected logic [7:0] error_state;

    function new(TriggerableQueue #(T) in_queue, TriggerableQueueBroadcaster #(T) out_broadcaster);
        this.in_queue = in_queue;
        this.out_broadcaster = out_broadcaster;
        error_state = 0;
    endfunction

    function automatic bit special_operand(logic [T::DATA_WIDTH - 1 : 0] word_value);
        return (&word_value[T::MANTISSA_WIDTH + T::EXPONENT_WIDTH - 1 : T::MANTISSA_WIDTH]) &&
               word_value[T::MANTISSA_WIDTH - 1];
    endfunction

    function automatic bit valid_operand(logic [T::DATA_WIDTH - 1 : 0] word_value);
        logic [T::MANTISSA_WIDTH - 1 : 0] mantissa;
        logic [T::EXPONENT_WIDTH - 1 : 0] exponent_value;
        mantissa = word_value[T::MANTISSA_WIDTH - 1 : 0];
        exponent_value = word_value[T::MANTISSA_WIDTH + T::EXPONENT_WIDTH - 1 : T::MANTISSA_WIDTH];
        if(exponent_value == '0) return mantissa == '0;
        return (mantissa >> max(0, T::MANTISSA_WIDTH - T::BASE_WIDTH)) != 0;
    endfunction

    function automatic logic [T::DATA_WIDTH - 1 : 0] multiply_values(alternate_base_fp_multiplier_io_in_t transaction);
        product_t exact_product, quotient, remainder_value, half, unit_value, normalize_min;
        exponent_t exponent_a, exponent_b, exponent_value, bias, max_exponent;
        logic [T::MANTISSA_WIDTH - 1 : 0] mantissa_a, mantissa_b;
        bit sign_value, inf_nan, zero_operand;
        error_state = 0;
        if($isunknown(transaction)) begin error_state = 1; return '0; end
        if(!valid_operand(transaction.a_i) || !valid_operand(transaction.b_i)) begin
            error_state = 2; // Exponent-zero/nonzero-mantissa and unnormalized inputs are undefined.
            return '0;
        end
        sign_value = transaction.a_i[T::DATA_WIDTH - 1] ^ transaction.b_i[T::DATA_WIDTH - 1];
        inf_nan = special_operand(transaction.a_i) || special_operand(transaction.b_i);
        exponent_a = exponent_t'({1'b0, transaction.a_i[T::MANTISSA_WIDTH + T::EXPONENT_WIDTH - 1 : T::MANTISSA_WIDTH]});
        exponent_b = exponent_t'({1'b0, transaction.b_i[T::MANTISSA_WIDTH + T::EXPONENT_WIDTH - 1 : T::MANTISSA_WIDTH]});
        mantissa_a = transaction.a_i[T::MANTISSA_WIDTH - 1 : 0];
        mantissa_b = transaction.b_i[T::MANTISSA_WIDTH - 1 : 0];
        bias = (exponent_t'(1) << (T::EXPONENT_WIDTH - 1)) - exponent_t'(1);
        max_exponent = (exponent_t'(1) << T::EXPONENT_WIDTH) - exponent_t'(1);
        zero_operand = exponent_a == 0 || exponent_b == 0;
        exponent_value = zero_operand ? exponent_t'(0) : exponent_a + exponent_b - bias;
        exact_product = mantissa_a * mantissa_b;
        unit_value = product_t'(1) << T::MANTISSA_WIDTH;
        normalize_min = product_t'(1) << (2 * T::MANTISSA_WIDTH - T::BASE_WIDTH);
        // Normalize an exact rational value, independently of the RTL's two-choice mux.
        while(exact_product != 0 && exact_product < normalize_min) begin
            exact_product = exact_product << T::BASE_WIDTH;
            if(!zero_operand) exponent_value--;
        end
        quotient = exact_product / unit_value;
        remainder_value = exact_product % unit_value;
        half = unit_value / product_t'(2);
        if(remainder_value > half || (remainder_value == half && quotient[0])) quotient++;
        if(quotient >= unit_value) begin
            quotient = quotient >> T::BASE_WIDTH;
            if(!zero_operand) exponent_value++;
        end
        // The single metadata bit preserves the combined class, including special * zero.
        if(inf_nan) begin
            exponent_value = max_exponent;
            quotient[T::MANTISSA_WIDTH - 1] = 1;
        end else if(zero_operand || exponent_value <= 0) begin
            exponent_value = 0;
            quotient = '0;
        end else if(exponent_value > max_exponent ||
                    (exponent_value == max_exponent && quotient[T::MANTISSA_WIDTH - 1])) begin
            exponent_value = max_exponent;
            quotient[T::MANTISSA_WIDTH - 1] = 1;
        end
        return {sign_value, exponent_value[T::EXPONENT_WIDTH - 1 : 0], quotient[T::MANTISSA_WIDTH - 1 : 0]};
    endfunction

    task automatic run();
        T io_in, io_out;
        alternate_base_fp_multiplier_io_in_t transaction_in;
        alternate_base_fp_multiplier_io_out_t transaction_out;
        forever begin
            in_queue.pop(io_in);
            io_out = new();
            io_out.end_last_sequence = io_in.end_last_sequence;
            while(io_in.alternate_base_fp_multiplier_io_in_q.size() > 0) begin
                transaction_in = io_in.alternate_base_fp_multiplier_io_in_q.pop_front();
                if(io_in.idle.pop_front()) continue;
                transaction_out.product_o = multiply_values(transaction_in);
                io_out.alternate_base_fp_multiplier_io_in_q.push_back(transaction_in);
                io_out.alternate_base_fp_multiplier_io_out_q.push_back(transaction_out);
                io_out.error_state.push_back(error_state);
            end
            out_broadcaster.push(io_out);
        end
    endtask
endclass
