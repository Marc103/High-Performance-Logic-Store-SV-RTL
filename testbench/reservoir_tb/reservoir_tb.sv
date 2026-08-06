////////////////////////////////////////////////////////////////
// rtl utilities include and imports
`include "rtl_utilities_pkg.sv"
import constant_functions_pkg::*;

////////////////////////////////////////////////////////////////
// interface include
`include "reservoir_inf.svh"

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

////////////////////////////////////////////////////////////////
// timescale
`timescale 1ns / 1ns

module reservoir_tb #(
    parameter DATA_WIDTH = 8,
    parameter WATERMARK_ENTRIES = 4,
    parameter BACKPRESSURE_ENTRIES = 2,
    parameter BURSTMARK = 2
) ();

    ////////////////////////////////////////////////////////////////
    // localparams
    localparam real CLK_PERIOD = 10;

    localparam type T = ReservoirIO #(
        .DATA_WIDTH(DATA_WIDTH),
        .WATERMARK_ENTRIES(WATERMARK_ENTRIES),
        .BACKPRESSURE_ENTRIES(BACKPRESSURE_ENTRIES),
        .BURSTMARK(BURSTMARK)
    );

    localparam type I = virtual reservoir_inf #(
        .DATA_WIDTH(DATA_WIDTH),
        .WATERMARK_ENTRIES(WATERMARK_ENTRIES),
        .BACKPRESSURE_ENTRIES(BACKPRESSURE_ENTRIES),
        .BURSTMARK(BURSTMARK)
    );

    ////////////////////////////////////////////////////////////////
    // clock generation
    logic clk = 0;
    always begin #(CLK_PERIOD/2); clk = ~clk; end

    ////////////////////////////////////////////////////////////////
    // interface
    reservoir_inf #(
        .DATA_WIDTH(DATA_WIDTH),
        .WATERMARK_ENTRIES(WATERMARK_ENTRIES),
        .BACKPRESSURE_ENTRIES(BACKPRESSURE_ENTRIES),
        .BURSTMARK(BURSTMARK)
    ) bfm (.clk_i(clk)); // bfm, "bus functional model"

    ////////////////////////////////////////////////////////////////
    // DUT
    reservoir #(
        .DATA_WIDTH(DATA_WIDTH),
        .WATERMARK_ENTRIES(WATERMARK_ENTRIES),
        .BACKPRESSURE_ENTRIES(BACKPRESSURE_ENTRIES),
        .BURSTMARK(BURSTMARK)
    ) dut (
        .clk_i(clk),
        .rst_i(bfm.rst_i),

        .fill_data_i(bfm.fill_data_i),
        .fill_valid_i(bfm.fill_valid_i),
        .fill_ready_o(bfm.fill_ready_o),

        .drain_ready_i(bfm.drain_ready_i),
        .drain_data_o(bfm.drain_data_o),
        .drain_valid_o(bfm.drain_valid_o),
        .drain_burstmark_o(bfm.drain_burstmark_o)
    );

    initial begin
        ////////////////////////////////////////////////////////////////
        // generator
        static TriggerableQueueBroadcaster #(T) dut_generator_out_broadcast = new();
        static ReservoirGenerator #(T) dut_generator = new(dut_generator_out_broadcast);

        static TriggerableQueueBroadcaster #(T) model_generator_out_broadcast = new();
        static ReservoirGenerator #(T) model_generator = new(model_generator_out_broadcast);

        ////////////////////////////////////////////////////////////////
        // driver
        static TriggerableQueue #(T) driver_in_queue = new();
        static ReservoirDriver #(T,I) driver = new(driver_in_queue, bfm);

        ////////////////////////////////////////////////////////////////
        // golden model
        static TriggerableQueue #(T) golden_in_queue = new();
        static TriggerableQueueBroadcaster #(T) golden_out_broadcast = new();
        static ReservoirModel #(T) golden = new(golden_in_queue, golden_out_broadcast);

        ////////////////////////////////////////////////////////////////
        // monitor
        static TriggerableQueueBroadcaster #(T) monitor_out_broadcast = new();
        static ReservoirMonitor #(T, I) monitor = new(monitor_out_broadcast, bfm);

        ////////////////////////////////////////////////////////////////
        // scoreboard
        static TriggerableQueue #(T) scoreboard_in_queue_dut = new();
        static TriggerableQueue #(T) scoreboard_in_queue_golden = new();
        static ReservoirScoreboard #(T) scoreboard = new(scoreboard_in_queue_dut, scoreboard_in_queue_golden);

        ////////////////////////////////////////////////////////////////
        // Queue Linkage
        dut_generator_out_broadcast.add_queue(driver_in_queue);
        model_generator_out_broadcast.add_queue(golden_in_queue);
        monitor_out_broadcast.add_queue(scoreboard_in_queue_dut);
        golden_out_broadcast.add_queue(scoreboard_in_queue_golden);

        ////////////////////////////////////////////////////////////////
        // Set up dump
        $dumpfile("waves.vcd");
        $dumpvars(0, reservoir_tb);


        ////////////////////////////////////////////////////////////////
        // Establish known testbench-side inputs before the first driven cycle.
        bfm.rst_i = 0;
        bfm.fill_data_i = '0;
        bfm.fill_valid_i = 0;
        bfm.drain_ready_i = 0;
        bfm.start_sequence = 0;
        bfm.end_sequence = 0;
        bfm.end_last_sequence = 0;
        bfm.idle = 1;
        @(posedge clk); // clean start just after posedge

        // Run
        fork
            dut_generator.run();
            model_generator.run();
            driver.run();
            golden.run();
            monitor.run();
            scoreboard.run();
        join_none

        #100000;
        $fatal(1, "Reservoir testbench timeout");

    end
endmodule
