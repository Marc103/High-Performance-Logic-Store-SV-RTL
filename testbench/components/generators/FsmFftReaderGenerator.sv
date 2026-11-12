import constant_functions_pkg::*;

class FsmFftReaderGenerator #(type T);
    `FSM_FFT_READER_IO_IN_STRUCT(T::SAMPLES_ADDR_WIDTH)
    TriggerableQueueBroadcaster #(T) out_broadcaster;
    int unsigned seed = 32'h619e_13ad;

    function new(TriggerableQueueBroadcaster #(T) out_broadcaster);
        this.out_broadcaster = out_broadcaster;
    endfunction

    function automatic int pick(int count);
        // Independent generator instances must emit identical streams.
        seed = seed * 32'd1664525 + 32'd1013904223;
        return int'((seed >> 8) % count);
    endfunction

    function automatic int run_length(int n, int m);
        // Raw go sampled at 0, busy rises at 1, done at 1 + butterflies*II.
        return (n / 2) * $clog2(n) * m * T::II_CYCLES + 2;
    endfunction

    task automatic add_io(ref T obj, input bit reset, bit go, int n, int m);
        fsm_fft_reader_io_in_t stimulus;
        stimulus.rst_i = reset;
        stimulus.go_i = go;
        stimulus.fft_point_size_i = (T::SAMPLES_ADDR_WIDTH + 1)'(n);
        stimulus.fft_whole_iterations_i = T::SAMPLES_ADDR_WIDTH'(m);
        obj.fsm_fft_reader_io_in_q.push_back(stimulus);
        obj.idle.push_back(!reset && !go);
    endtask

    task automatic wait_clocks(ref T obj, input int count, int n, int m);
        repeat(count) add_io(obj, 0, 0, n, m);
    endtask

    task automatic send_run(ref T obj, input int n, int m, int gap = 0, int busy_pulse = -1);
        for(int i = 0; i < run_length(n, m) + T::READ_LATENCY + 4 + gap; i++)
            add_io(obj, 0, i == 0 || i == busy_pulse, n, m);
    endtask

    task automatic held_go(ref T obj, input int n, int m);
        int second_done;
        second_done = 2 + 2 * (run_length(n, m) - 2);
        // A level held through completion starts exactly one further run.
        for(int i = 0; i <= second_done + T::READ_LATENCY + 4; i++)
            add_io(obj, 0, i < second_done, n, m);
    endtask

    task automatic abort_run(ref T obj, input int n, int m, int offset, int reset_clocks = 1);
        for(int i = 0; i < offset; i++) add_io(obj, 0, i == 0, n, m);
        repeat(reset_clocks) add_io(obj, 1, 0, n, m);
        wait_clocks(obj, T::READ_LATENCY + 4, n, m);
        send_run(obj, 2, 1);
    endtask

    task automatic run();
        T obj;
        int n, m, small_n, boundary, mode;
        obj = new();
        repeat(3) add_io(obj, 1, 0, 2, 1);
        wait_clocks(obj, 3, 2, 1);
        send_run(obj, 2, 1);
        send_run(obj, T::MAX_FFT_SIZE, T::DATA_DEPTH / T::MAX_FFT_SIZE);
        held_go(obj, 2, 1);
        send_run(obj, 2, 1, 0, 2);
        send_run(obj, 2, 1, 3, 3);
        // Split a transaction across objects; these are continuous clocks, not reset boundaries.
        add_io(obj, 0, 1, 2, 1);
        out_broadcaster.push(obj);
        obj = new();
        wait_clocks(obj, run_length(2, 1) + T::READ_LATENCY + 4, 2, 1);
        // Exhaust every supported power-of-two N and fitting positive whole-FFT count.
        for(int log_n = 1; log_n <= T::MAX_FFT_LOG2; log_n++) begin
            n = 1 << log_n;
            for(m = 1; m <= T::DATA_DEPTH / n; m++) send_run(obj, n, m);
        end
        small_n = T::MAX_FFT_SIZE < 8 ? T::MAX_FFT_SIZE : 8;
        for(int offset = 1; offset <= 2 * T::II_CYCLES + T::READ_LATENCY + 6; offset++)
            abort_run(obj, small_n, 1, offset, 1 + (offset % 2));
        // Reset immediately around whole/stage boundaries and final completion.
        n = T::MAX_FFT_SIZE < 4 ? T::MAX_FFT_SIZE : 4;
        m = T::DATA_DEPTH / n >= 2 ? 2 : 1;
        for(int which_boundary = 0; which_boundary < 3; which_boundary++) begin
            case(which_boundary)
                0: boundary = 1 + (n / 2) * T::II_CYCLES;
                1: boundary = 1 + (n / 2) * m * T::II_CYCLES;
                default: boundary = run_length(n, m) - 1;
            endcase
            for(int delta = -1; delta <= 1; delta++) abort_run(obj, n, m, boundary + delta);
        end
        out_broadcaster.push(obj);
        obj = new();
        for(int iteration = 0; iteration < T::RANDOM_TRANSACTIONS; iteration++) begin
            n = 1 << (1 + pick(T::MAX_FFT_LOG2));
            m = 1 + pick(T::DATA_DEPTH / n);
            mode = pick(4);
            case(mode)
                0: send_run(obj, n, m, pick(2 * T::II_CYCLES + 1));
                1: held_go(obj, n, m);
                2: send_run(obj, n, m, 0, 2);
                3: abort_run(obj, n, m, 1 + pick(run_length(n, m) + T::READ_LATENCY));
            endcase
        end
        // go high during reset cannot issue requests, but can launch after reset releases.
        repeat(2) add_io(obj, 1, 1, 2, 1);
        add_io(obj, 0, 1, 2, 1);
        wait_clocks(obj, run_length(2, 1) + T::READ_LATENCY + 6, 2, 1);
        obj.end_last_sequence = 1;
        out_broadcaster.push(obj);
    endtask
endclass
