import constant_functions_pkg::*;

class FsmFftWriterGenerator #(type T);
    typedef logic [T::DATA_WIDTH - 1 : 0] word_t;
    typedef logic [T::ADDR_WIDTH - 1 : 0] addr_t;
    `FSM_FFT_WRITER_IO_IN_STRUCT(T::DATA_WIDTH, T::ADDR_WIDTH)
    TriggerableQueueBroadcaster #(T) out_broadcaster;
    int unsigned seed = 32'h103f_971b;

    function new(TriggerableQueueBroadcaster #(T) out_broadcaster);
        this.out_broadcaster = out_broadcaster;
    endfunction

    function automatic int pick(int count);
        // The DUT and model generators have independent, identical deterministic streams.
        seed = seed * 32'd1664525 + 32'd1013904223;
        return int'((seed >> 8) % count);
    endfunction

    function automatic word_t random_word();
        word_t value;
        for(int i = 0; i < T::DATA_WIDTH; i++) value[i] = 1'(pick(2));
        return value;
    endfunction

    function automatic addr_t random_addr();
        addr_t value;
        for(int i = 0; i < T::ADDR_WIDTH; i++) value[i] = 1'(pick(2));
        return value;
    endfunction

    task automatic add_io(ref T obj, input bit reset, bit valid, addr_t a, addr_t b, word_t y0, word_t y1);
        fsm_fft_writer_io_in_t value;
        value.rst_i = reset;
        value.a_wr_addr_i = a;
        value.b_wr_addr_i = b;
        value.valid_i = valid;
        value.y0_i = y0;
        value.y1_i = y1;
        obj.fsm_fft_writer_io_in_q.push_back(value);
        obj.idle.push_back(!reset && !valid);
    endtask

    task automatic wait_clocks(ref T obj, input int count);
        repeat(count) add_io(obj, 0, 0, 'x, 'x, 'x, 'x);
    endtask

    task automatic send_bundle(ref T obj, input addr_t a, addr_t b, word_t y0, word_t y1,
                               int gap = 2, int high_clocks = 1, bit early_a = 0);
        // A need not exist on acceptance. Change live result data before the second command.
        add_io(obj, 0, 1, early_a ? a : addr_t'('x), b, y0, y1);
        add_io(obj, 0, high_clocks > 1, a, 'x, ~y0, ~y1);
        for(int i = 2; i < high_clocks; i++) add_io(obj, 0, 1, 'x, 'x, 'x, 'x);
        if(high_clocks > 1) wait_clocks(obj, 1); // Release held valid before a fresh strobe.
        wait_clocks(obj, gap);
    endtask

    task automatic reset_scenario(ref T obj, input int phase, addr_t a, addr_t b, word_t y0, word_t y1);
        add_io(obj, 0, 1, 'x, b, y0, y1);
        if(phase >= 1) add_io(obj, 0, 0, a, 'x, ~y0, ~y1);
        if(phase >= 2) wait_clocks(obj, 1);
        // phase 0: cancel B plus pending A; phase 1: B committed, cancel A;
        // phase 2: both committed. valid during reset must not launch a bundle.
        repeat(1 + phase % 2) add_io(obj, 1, 1, 'x, 'x, 'x, 'x);
        wait_clocks(obj, 2);
    endtask

    task automatic run();
        T obj;
        word_t y0, y1, walking;
        addr_t a, b, address_bit;
        int mode;
        obj = new();
        repeat(3) add_io(obj, 1, 0, 'x, 'x, 'x, 'x);
        wait_clocks(obj, 3);
        send_bundle(obj, '0, '1, '0, '1);
        send_bundle(obj, '1, '0, '1, '0, 0);
        send_bundle(obj, '0, '1, '0, '0, 0);
        send_bundle(obj, '1, '0, '1, '1, 0);
        for(int i = 0; i < T::DATA_WIDTH; i++) begin
            walking = '0;
            walking[i] = 1;
            send_bundle(obj, '0, '1, walking, ~walking, i % 3);
        end
        for(int i = 0; i < T::ADDR_WIDTH; i++) begin
            address_bit = '0;
            address_bit[i] = 1;
            send_bundle(obj, address_bit, ~address_bit, random_word(), random_word(), 0);
        end
        // End this object with a pending A write and a B command awaiting memory consumption.
        add_io(obj, 0, 1, 'x, '1, '0, '1);
        out_broadcaster.push(obj);
        obj = new();
        add_io(obj, 0, 0, '0, 'x, '1, '0);
        wait_clocks(obj, 2);
        for(int i = 0; i < 16; i++)
            send_bundle(obj, random_addr(), random_addr(), random_word(), random_word(), 2);
        send_bundle(obj, '1, '0, '0, '1, 0, 2);
        send_bundle(obj, '0, '1, '1, '0, 4, 7);
        for(int phase = 0; phase < 3; phase++)
            reset_scenario(obj, phase, '0, '1, '1, '0);
        // Reset clears sampled-valid history: high on release accepts a fresh bundle.
        add_io(obj, 1, 1, 'x, 'x, 'x, 'x);
        send_bundle(obj, '1, '0, '0, '1, 2, 1);
        out_broadcaster.push(obj);
        obj = new();
        for(int i = 0; i < T::RANDOM_TRANSACTIONS; i++) begin
            a = random_addr(); b = random_addr(); y0 = random_word(); y1 = random_word();
            mode = pick(8);
            case(mode)
                0: send_bundle(obj, a, b, y0, y1, 0);
                1: send_bundle(obj, a, b, y0, y1, 2);
                2: send_bundle(obj, a, b, y0, y1, 1 + pick(12));
                3: send_bundle(obj, a, b, y0, y1, 0, 3 + pick(6));
                4: reset_scenario(obj, 0, a, b, y0, y1);
                5: reset_scenario(obj, 1, a, b, y0, y1);
                6: send_bundle(obj, a, a, y0, y1, 0); // Repeated-address last write wins.
                7: send_bundle(obj, a, b, y0, y1, 4, 1, 1);
            endcase
        end
        wait_clocks(obj, 4); // Drain the last registered command into memory.
        obj.end_last_sequence = 1;
        out_broadcaster.push(obj);
    endtask
endclass
