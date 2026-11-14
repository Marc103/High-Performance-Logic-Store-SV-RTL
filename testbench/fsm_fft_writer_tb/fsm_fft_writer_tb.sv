`timescale 1ns/1ns
`include "rtl_utilities_pkg.sv"
import constant_functions_pkg::*;
`include "fsm_fft_writer_inf.svh"
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

`include "fsm/fsm_fft_writer/fsm_fft_writer.sv"

module fsm_fft_writer_tb #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 4,
    parameter RANDOM_TRANSACTIONS = 256
) ();
    localparam real CLK_PERIOD = 10;
    localparam type T = FsmFftWriterIO #(
        .DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH), .RANDOM_TRANSACTIONS(RANDOM_TRANSACTIONS)
    );
    localparam type I = virtual fsm_fft_writer_inf #(
        .DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)
    );
    logic clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;
    fsm_fft_writer_inf #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) bfm(.clk_i(clk));
    fsm_fft_writer #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) dut(
        .clk_i(clk), .rst_i(bfm.rst_i), .a_wr_addr_i(bfm.a_wr_addr_i), .b_wr_addr_i(bfm.b_wr_addr_i),
        .valid_i(bfm.valid_i), .y0_i(bfm.y0_i), .y1_i(bfm.y1_i),
        .wr_addr_o(bfm.wr_addr_o), .wr_data_o(bfm.wr_data_o), .wr_en_o(bfm.wr_en_o)
    );
    initial begin
        static TriggerableQueueBroadcaster #(T) dut_generator_out_broadcast = new();
        static FsmFftWriterGenerator #(T) dut_generator = new(dut_generator_out_broadcast);
        static TriggerableQueueBroadcaster #(T) model_generator_out_broadcast = new();
        static FsmFftWriterGenerator #(T) model_generator = new(model_generator_out_broadcast);
        static TriggerableQueue #(T) driver_in_queue = new();
        static FsmFftWriterDriver #(T,I) driver = new(driver_in_queue, bfm);
        static TriggerableQueue #(T) golden_in_queue = new();
        static TriggerableQueueBroadcaster #(T) golden_out_broadcast = new();
        static FsmFftWriterModel #(T) golden = new(golden_in_queue, golden_out_broadcast);
        static TriggerableQueueBroadcaster #(T) monitor_out_broadcast = new();
        static FsmFftWriterMonitor #(T,I) monitor = new(monitor_out_broadcast, bfm);
        static TriggerableQueue #(T) scoreboard_in_queue_dut = new();
        static TriggerableQueue #(T) scoreboard_in_queue_golden = new();
        static FsmFftWriterScoreboard #(T) scoreboard = new(scoreboard_in_queue_dut, scoreboard_in_queue_golden);

        if(DATA_WIDTH < 1 || ADDR_WIDTH < 1) $fatal(1, "DATA_WIDTH and ADDR_WIDTH must be positive");
        if(RANDOM_TRANSACTIONS < 0) $fatal(1, "RANDOM_TRANSACTIONS must be nonnegative");
        dut_generator_out_broadcast.add_queue(driver_in_queue);
        model_generator_out_broadcast.add_queue(golden_in_queue);
        monitor_out_broadcast.add_queue(scoreboard_in_queue_dut);
        golden_out_broadcast.add_queue(scoreboard_in_queue_golden);
        $dumpfile("waves.vcd");
        $dumpvars(0, fsm_fft_writer_tb);
        $display("DATA_WIDTH=%0d ADDR_WIDTH=%0d RANDOM=%0d", DATA_WIDTH, ADDR_WIDTH, RANDOM_TRANSACTIONS);
        bfm.rst_i = 1;
        bfm.valid_i = 0;
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
        #(CLK_PERIOD * (128.0 * (RANDOM_TRANSACTIONS + DATA_WIDTH + ADDR_WIDTH + 64)));
        $fatal(1, "Testbench timed out before scoreboard completion");
    end
endmodule
