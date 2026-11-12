`timescale 1ns/1ns
`include "rtl_utilities_pkg.sv"
import constant_functions_pkg::*;
`include "fsm_fft_reader_inf.svh"
`include "utilities_pkg.svh"
`include "io_pkg.svh"
`include "drivers_pkg.svh"
`include "generators_pkg.svh"
`include "golden_models_pkg.svh"
`include "monitors_pkg.svh"
`include "scoreboards_pkg.svh"
import utilities_pkg::*;
import io_pkg::*;
import drivers_pkg::*;
import generators_pkg::*;
import golden_models_pkg::*;
import monitors_pkg::*;
import scoreboards_pkg::*;

`include "fsm/fsm_fft_reader/fsm_fft_reader.sv"

module fsm_fft_reader_tb #(
    parameter DATA_WIDTH = 16,
    parameter SAMPLES_ADDR_WIDTH = 4,
    parameter TWIDDLES_ADDR_WIDTH = 3,
    parameter II_CYCLES = 4,
    parameter READ_LATENCY = 1,
    parameter RANDOM_TRANSACTIONS = 32
) ();
    localparam real CLK_PERIOD = 10;
    localparam type T = FsmFftReaderIO #(
        .DATA_WIDTH(DATA_WIDTH),
        .SAMPLES_ADDR_WIDTH(SAMPLES_ADDR_WIDTH),
        .TWIDDLES_ADDR_WIDTH(TWIDDLES_ADDR_WIDTH),
        .II_CYCLES(II_CYCLES),
        .READ_LATENCY(READ_LATENCY),
        .RANDOM_TRANSACTIONS(RANDOM_TRANSACTIONS)
    );
    localparam type I = virtual fsm_fft_reader_inf #(
        .DATA_WIDTH(DATA_WIDTH),
        .SAMPLES_ADDR_WIDTH(SAMPLES_ADDR_WIDTH),
        .TWIDDLES_ADDR_WIDTH(TWIDDLES_ADDR_WIDTH),
        .II_CYCLES(II_CYCLES),
        .READ_LATENCY(READ_LATENCY)
    );
    logic clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;
    fsm_fft_reader_inf #(
        .DATA_WIDTH(DATA_WIDTH),
        .SAMPLES_ADDR_WIDTH(SAMPLES_ADDR_WIDTH),
        .TWIDDLES_ADDR_WIDTH(TWIDDLES_ADDR_WIDTH),
        .II_CYCLES(II_CYCLES),
        .READ_LATENCY(READ_LATENCY)
    ) bfm(.clk_i(clk));
    fsm_fft_reader #(
        .DATA_WIDTH(DATA_WIDTH),
        .SAMPLES_ADDR_WIDTH(SAMPLES_ADDR_WIDTH),
        .TWIDDLES_ADDR_WIDTH(TWIDDLES_ADDR_WIDTH),
        .II_CYCLES(II_CYCLES),
        .READ_LATENCY(READ_LATENCY)
    ) dut (
        .clk_i(clk), .rst_i(bfm.rst_i), .go_i(bfm.go_i),
        .fft_point_size_i(bfm.fft_point_size_i), .fft_whole_iterations_i(bfm.fft_whole_iterations_i),
        .a_b_rd_addr_o(bfm.a_b_rd_addr_o), .a_b_rd_en_o(bfm.a_b_rd_en_o),
        .a_valid_o(bfm.a_valid_o), .b_valid_o(bfm.b_valid_o),
        .w_rd_addr_o(bfm.w_rd_addr_o), .w_rd_en_o(bfm.w_rd_en_o), .w_valid_o(bfm.w_valid_o),
        .busy_o(bfm.busy_o), .fft_done_o(bfm.fft_done_o)
    );
    initial begin
        static TriggerableQueueBroadcaster #(T) dut_generator_out_broadcast = new();
        static FsmFftReaderGenerator #(T) dut_generator = new(dut_generator_out_broadcast);
        static TriggerableQueueBroadcaster #(T) model_generator_out_broadcast = new();
        static FsmFftReaderGenerator #(T) model_generator = new(model_generator_out_broadcast);
        static TriggerableQueue #(T) driver_in_queue = new();
        static FsmFftReaderDriver #(T,I) driver = new(driver_in_queue, bfm);
        static TriggerableQueue #(T) golden_in_queue = new();
        static TriggerableQueueBroadcaster #(T) golden_out_broadcast = new();
        static FsmFftReaderModel #(T) golden = new(golden_in_queue, golden_out_broadcast);
        static TriggerableQueueBroadcaster #(T) monitor_out_broadcast = new();
        static FsmFftReaderMonitor #(T,I) monitor = new(monitor_out_broadcast, bfm);
        static TriggerableQueue #(T) scoreboard_in_queue_dut = new();
        static TriggerableQueue #(T) scoreboard_in_queue_golden = new();
        static FsmFftReaderScoreboard #(T) scoreboard = new(scoreboard_in_queue_dut, scoreboard_in_queue_golden);

        // Bound exhaustive stimulus size; the RTL's address-width contract is wider.
        if(SAMPLES_ADDR_WIDTH < 1 || SAMPLES_ADDR_WIDTH > 8)
            $fatal(1, "This exhaustive TB supports SAMPLES_ADDR_WIDTH=1..8");
        if(TWIDDLES_ADDR_WIDTH < 1) $fatal(1, "TWIDDLES_ADDR_WIDTH must be positive");
        if(II_CYCLES < 4 || II_CYCLES > 1024) $fatal(1, "This TB supports II_CYCLES=4..1024");
        if(READ_LATENCY < 1) $fatal(1, "READ_LATENCY must be positive");
        if(RANDOM_TRANSACTIONS < 0) $fatal(1, "RANDOM_TRANSACTIONS must be nonnegative");
        dut_generator_out_broadcast.add_queue(driver_in_queue);
        model_generator_out_broadcast.add_queue(golden_in_queue);
        monitor_out_broadcast.add_queue(scoreboard_in_queue_dut);
        golden_out_broadcast.add_queue(scoreboard_in_queue_golden);
        $dumpfile("waves.vcd");
        $dumpvars(0, fsm_fft_reader_tb);
        $display("S=%0d W=%0d I=%0d R=%0d RANDOM=%0d", SAMPLES_ADDR_WIDTH,
                 TWIDDLES_ADDR_WIDTH, II_CYCLES, READ_LATENCY, RANDOM_TRANSACTIONS);
        bfm.rst_i = 1;
        bfm.go_i = 0;
        bfm.idle = 1;
        repeat(2) @(posedge clk);
        fork
            dut_generator.run();
            model_generator.run();
            driver.run();
            golden.run();
            monitor.run();
            scoreboard.run();
        join_none
        #(CLK_PERIOD * (128.0 * (RANDOM_TRANSACTIONS + T::DATA_DEPTH + READ_LATENCY + II_CYCLES + 64) *
                        (T::MAX_SCHEDULE_CYCLES + READ_LATENCY + II_CYCLES + 16)));
        $fatal(1, "Testbench timed out before scoreboard completion");
    end
endmodule
