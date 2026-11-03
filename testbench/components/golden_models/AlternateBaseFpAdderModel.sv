import constant_functions_pkg::*;

class AlternateBaseFpAdderModel #(type T);
    `ALTERNATE_BASE_FP_ADDER_IO_IN_STRUCT(T::DATA_WIDTH)
    `ALTERNATE_BASE_FP_ADDER_IO_OUT_STRUCT(T::DATA_WIDTH)
    // Exact common-scale integers avoid host floating-point precision limits.
    // The testbench bounds EXPONENT_WIDTH to 1..10 to keep the vector practical.
    typedef logic [T::MODEL_EXACT_WIDTH - 1 : 0] exact_t;
    TriggerableQueue #(T) in_queue;
    TriggerableQueueBroadcaster #(T) out_broadcaster;
    protected logic [7:0] error_state;

    function new(TriggerableQueue #(T) in_queue, TriggerableQueueBroadcaster #(T) out_broadcaster);
        this.in_queue = in_queue;
        this.out_broadcaster = out_broadcaster;
        error_state = 0;
    endfunction

    function automatic bit finite_operand(logic [T::DATA_WIDTH - 1 : 0] word_value);
        logic [T::MANTISSA_WIDTH - 1 : 0] mantissa;
        int exponent_value;
        mantissa = word_value[T::MANTISSA_WIDTH - 1 : 0];
        exponent_value = int'(word_value[T::MANTISSA_WIDTH + T::EXPONENT_WIDTH - 1 : T::MANTISSA_WIDTH]);
        if(mantissa == '0) return 1;
        if(exponent_value == T::MAX_EXPONENT && mantissa[T::MANTISSA_WIDTH - 1]) return 0;
        if(exponent_value == 0 && !mantissa[T::MANTISSA_WIDTH - 1]) return 0;
        return (mantissa >> max(0, T::MANTISSA_WIDTH - T::BASE_WIDTH)) != 0;
    endfunction

    function automatic logic [T::DATA_WIDTH - 1 : 0] add_values(alternate_base_fp_adder_io_in_t transaction);
        exact_t magnitude_a, magnitude_b, magnitude, quotient, remainder_value, half;
        int exponent_a, exponent_b, exponent_value, shift;
        bit sign_a, sign_b, sign_value;
        error_state = 0;
        if($isunknown(transaction)) begin error_state = 1; return '0; end
        if(!finite_operand(transaction.a_i) || !finite_operand(transaction.b_i)) begin
            error_state = 2; // NaN/Inf, subnormal, or unnormalized operand: outside this model's contract.
            return '0;
        end
        sign_a = transaction.a_i[T::DATA_WIDTH - 1];
        sign_b = transaction.b_i[T::DATA_WIDTH - 1];
        exponent_a = int'(transaction.a_i[T::MANTISSA_WIDTH + T::EXPONENT_WIDTH - 1 : T::MANTISSA_WIDTH]);
        exponent_b = int'(transaction.b_i[T::MANTISSA_WIDTH + T::EXPONENT_WIDTH - 1 : T::MANTISSA_WIDTH]);
        magnitude_a = '0;
        magnitude_b = '0;
        magnitude_a[T::MANTISSA_WIDTH - 1 : 0] = transaction.a_i[T::MANTISSA_WIDTH - 1 : 0];
        magnitude_b[T::MANTISSA_WIDTH - 1 : 0] = transaction.b_i[T::MANTISSA_WIDTH - 1 : 0];
        magnitude_a = magnitude_a << (T::BASE_WIDTH * exponent_a);
        magnitude_b = magnitude_b << (T::BASE_WIDTH * exponent_b);
        if(sign_a == sign_b) begin
            magnitude = magnitude_a + magnitude_b;
            sign_value = sign_a;
        end else if(magnitude_a >= magnitude_b) begin
            magnitude = magnitude_a - magnitude_b;
            sign_value = sign_a;
        end else begin
            magnitude = magnitude_b - magnitude_a;
            sign_value = sign_b;
        end
        if(magnitude == '0) return '0;
        exponent_value = 0;
        shift = 0;
        while((magnitude >> shift) >= (exact_t'(1) << T::MANTISSA_WIDTH)) begin
            exponent_value++;
            shift += T::BASE_WIDTH;
        end
        quotient = magnitude >> shift;
        if(shift > 0) begin
            remainder_value = magnitude & ((exact_t'(1) << shift) - exact_t'(1));
            half = exact_t'(1) << (shift - 1);
            if(remainder_value > half || (remainder_value == half && quotient[0])) quotient++;
        end
        if(quotient >= (exact_t'(1) << T::MANTISSA_WIDTH)) begin
            quotient = quotient >> T::BASE_WIDTH;
            exponent_value++;
        end
        // Preserve the format's existing exponent/MSB reserved-value convention.
        if(exponent_value == 0 && !quotient[T::MANTISSA_WIDTH - 1]) begin
            exponent_value = 0;
            quotient = '0;
        end else if(exponent_value > T::MAX_EXPONENT ||
                    (exponent_value == T::MAX_EXPONENT && quotient[T::MANTISSA_WIDTH - 1])) begin
            exponent_value = T::MAX_EXPONENT;
            quotient[T::MANTISSA_WIDTH - 1] = 1;
        end
        return {sign_value, T::EXPONENT_WIDTH'(exponent_value), quotient[T::MANTISSA_WIDTH - 1 : 0]};
    endfunction

    task automatic run();
        T io_in, io_out;
        alternate_base_fp_adder_io_in_t transaction_in;
        alternate_base_fp_adder_io_out_t transaction_out;
        forever begin
            in_queue.pop(io_in);
            io_out = new();
            io_out.end_last_sequence = io_in.end_last_sequence;
            while(io_in.alternate_base_fp_adder_io_in_q.size() > 0) begin
                transaction_in = io_in.alternate_base_fp_adder_io_in_q.pop_front();
                if(io_in.idle.pop_front()) continue;
                transaction_out.sum_o = add_values(transaction_in);
                io_out.alternate_base_fp_adder_io_in_q.push_back(transaction_in);
                io_out.alternate_base_fp_adder_io_out_q.push_back(transaction_out);
                io_out.error_state.push_back(error_state);
            end
            out_broadcaster.push(io_out);
        end
    endtask
endclass
