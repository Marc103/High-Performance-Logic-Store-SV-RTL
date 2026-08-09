////////////////////////////////////////////////////////////////
// rtl utilities include and imports
`include "rtl_utilities_pkg.sv"
import constant_functions_pkg::*;

////////////////////////////////////////////////////////////////
// interface include
`include "queue_push_coupler_inf.svh"

////////////////////////////////////////////////////////////////
// package includes
`include "utilities_pkg.svh"
`include "io_pkg.svh"
`include "drivers_pkg.svh"
`include "generators_pkg.svh"
`include "golden_models_pkg.svh"
`include "monitors_pkg.svh"
`include "scoreboards_pkg.svh"

////////////////////////////////////////////////////////////////
// imports
import utilities_pkg::*;
import io_pkg::*;
import drivers_pkg::*;
import generators_pkg::*;
import golden_models_pkg::*;
import monitors_pkg::*;
import scoreboards_pkg::*;

////////////////////////////////////////////////////////////////
// RTL includes
`include "memory_systems/reservoir/reservoir.sv"
`include "memory_systems/queue_push_coupler/queue_push_coupler.sv"

////////////////////////////////////////////////////////////////
// timescale
`timescale 1ns / 1ns

module queue_push_coupler_tb #(
    parameter DATA_WIDTH = 8,
    parameter SIMPLE = 0,
    parameter ASYNC = 0,
    parameter BURST_SIZE = 4,
    parameter ADDR_WIDTH = 4
) ();

    localparam real CLK_PERIOD = 10;

    localparam type T = QueuePushCouplerIO #(
        .DATA_WIDTH(DATA_WIDTH),
        .SIMPLE(SIMPLE),
        .ASYNC(ASYNC),
        .BURST_SIZE(BURST_SIZE),
        .ADDR_WIDTH(ADDR_WIDTH)
    );

    localparam type I = virtual queue_push_coupler_inf #(
        .DATA_WIDTH(DATA_WIDTH),
        .SIMPLE(SIMPLE),
        .ASYNC(ASYNC),
        .BURST_SIZE(BURST_SIZE),
        .ADDR_WIDTH(ADDR_WIDTH)
    );

    logic clk = 0;
    always begin #(CLK_PERIOD/2); clk = ~clk; end

    queue_push_coupler_inf #(
        .DATA_WIDTH(DATA_WIDTH),
        .SIMPLE(SIMPLE),
        .ASYNC(ASYNC),
        .BURST_SIZE(BURST_SIZE),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) bfm (.wr_clk_i(clk));

    queue_push_coupler #(
        .DATA_WIDTH(DATA_WIDTH),
        .SIMPLE(SIMPLE),
        .ASYNC(ASYNC),
        .BURST_SIZE(BURST_SIZE),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .wr_clk_i(clk),
        .wr_rst_i(bfm.wr_rst_i),

        .wr_data_i(bfm.wr_data_i),
        .wr_valid_i(bfm.wr_valid_i),
        .ready_o(bfm.ready_o),
        .burstready_o(bfm.burstready_o),

        .full_i(bfm.full_i),
        .lookahead_i(bfm.lookahead_i),
        .wr_data_o(bfm.wr_data_o),
        .push_o(bfm.push_o),
        .more_than_or_eq_o(bfm.more_than_or_eq_o)
    );

    initial begin
        static TriggerableQueueBroadcaster #(T) dut_generator_out_broadcast = new();
        static QueuePushCouplerGenerator #(T) dut_generator = new(dut_generator_out_broadcast);

        static TriggerableQueueBroadcaster #(T) model_generator_out_broadcast = new();
        static QueuePushCouplerGenerator #(T) model_generator = new(model_generator_out_broadcast);

        static TriggerableQueue #(T) driver_in_queue = new();
        static QueuePushCouplerDriver #(T, I) driver = new(driver_in_queue, bfm);

        static TriggerableQueue #(T) golden_in_queue = new();
        static TriggerableQueueBroadcaster #(T) golden_out_broadcast = new();
        static QueuePushCouplerModel #(T) golden = new(golden_in_queue, golden_out_broadcast);

        static TriggerableQueueBroadcaster #(T) monitor_out_broadcast = new();
        static QueuePushCouplerMonitor #(T, I) monitor = new(monitor_out_broadcast, bfm);

        static TriggerableQueue #(T) scoreboard_in_queue_dut = new();
        static TriggerableQueue #(T) scoreboard_in_queue_golden = new();
        static QueuePushCouplerScoreboard #(T) scoreboard = new(
            scoreboard_in_queue_dut,
            scoreboard_in_queue_golden
        );

        dut_generator_out_broadcast.add_queue(driver_in_queue);
        model_generator_out_broadcast.add_queue(golden_in_queue);
        monitor_out_broadcast.add_queue(scoreboard_in_queue_dut);
        golden_out_broadcast.add_queue(scoreboard_in_queue_golden);

        $dumpfile("waves.vcd");
        $dumpvars(0, queue_push_coupler_tb);

        bfm.wr_rst_i = 0;
        bfm.wr_data_i = '0;
        bfm.wr_valid_i = 0;
        bfm.full_i = 0;
        bfm.lookahead_i = 0;
        bfm.start_sequence = 0;
        bfm.end_sequence = 0;
        bfm.end_last_sequence = 0;
        bfm.idle = 1;
        @(posedge clk);

        fork
            dut_generator.run();
            model_generator.run();
            driver.run();
            golden.run();
            monitor.run();
            scoreboard.run();
        join_none

        #100000;
        $fatal(1, "QueuePushCoupler testbench timeout");
    end
endmodule
