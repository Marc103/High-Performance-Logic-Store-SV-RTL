////////////////////////////////////////////////////////////////
// rtl utilities include and imports
`include "rtl_utilities_pkg.svh"
import constant_functions_pkg::*;

////////////////////////////////////////////////////////////////
// interface include 
`include "multistage_fanout_inf.svh"

////////////////////////////////////////////////////////////////
// package includes
`include "utilities_pkg.svh"
`include "drivers_pkg.svh"
`include "generators_pkg.svh"
`include "golden_models_pkg.svh"
`include "monitors_pkg.svh"
`include "scoreboards_pkg.svh"

////////////////////////////////////////////////////////////////
// imports
import utilities_pkg::*;
import drivers_pkg::*;
import generators_pkg::*;
import golden_models_pkg::*;
import monitors_pkg::*;
import scoreboards_pkg::*;

////////////////////////////////////////////////////////////////
// RTL includes
`include "data_movers/io_circuits/multistage_fanout/multistage_fanout.sv"

////////////////////////////////////////////////////////////////
// timescale 
`timescale 1ns / 1ns

module multistage_fanout_tb();

    ////////////////////////////////////////////////////////////////
    // localparams
    localparam DATA_WIDTH = 8;
    localparam FANOUT_SIZE = 16;
    localparam FANOUT_FACTOR = 4;
    localparam IMMEDIATE_START_FANOUT = 0;

    localparam real CLK_PERIOD = 10;

    localparam type T = MultistageFanoutClass #(
        .DATA_WIDTH(DATA_WIDTH),
        .FANOUT_SIZE(FANOUT_SIZE),
        .FANOUT_FACTOR(FANOUT_FACTOR),
        .IMMEDIATE_START_FANOUT(IMMEDIATE_START_FANOUT)
    );

    localparam type I = virtual multistage_fanout_inf #(
        .DATA_WIDTH(DATA_WIDTH),
        .FANOUT_SIZE(FANOUT_SIZE),
        .FANOUT_FACTOR(FANOUT_FACTOR),
        .IMMEDIATE_START_FANOUT(IMMEDIATE_START_FANOUT)
    );

    ////////////////////////////////////////////////////////////////
    // clock generation and reset
    logic clk = 0;
    logic rst = 0;
    always begin #(CLK_PERIOD/2); clk = ~clk; end

    ////////////////////////////////////////////////////////////////
    // interface
    multistage_fanout_inf #(
        .DATA_WIDTH(DATA_WIDTH),
        .FANOUT_SIZE(FANOUT_SIZE),
        .FANOUT_FACTOR(FANOUT_FACTOR),
        .IMMEDIATE_START_FANOUT(IMMEDIATE_START_FANOUT)
    ) bfm (.clk_i(clk)); // bfm, "bus functional model"
    
    ////////////////////////////////////////////////////////////////
    // DUT
    multistage_fanout #(
        .DATA_WIDTH(DATA_WIDTH),
        .FANOUT_SIZE(FANOUT_SIZE),
        .FANOUT_FACTOR(FANOUT_FACTOR),
        .IMMEDIATE_START_FANOUT(IMMEDIATE_START_FANOUT)
    ) dut (
        .clk_i(clk),

        .data_i(bfm.data_i),
        .valid_i(bfm.valid_i),

        .data_o(bfm.data_o),
        .valid_o(bfm.valid_o)
    );

    initial begin
        ////////////////////////////////////////////////////////////////
        // generator
        static TriggerableQueueBroadcaster #(T) generator_out_broadcast = new();
        static MultistageFanoutGenerator #(T) generator = new(generator_out_broadcast);

        ////////////////////////////////////////////////////////////////
        // driver
        static TriggerableQueue #(T) driver_in_queue = new();
        static MultistageFanoutDriver #(T, I) driver = new(driver_in_queue, bfm);

        ////////////////////////////////////////////////////////////////
        // golden model
        static TriggerableQueue #(T) golden_in_queue = new();
        static TriggerableQueueBroadcaster #(T) golden_out_broadcast = new();
        static MultistageFanoutModel #(T) golden = new(golden_in_queue, golden_out_broadcast);

        ////////////////////////////////////////////////////////////////
        // monitor
        static TriggerableQueueBroadcaster #(T) monitor_out_broadcast = new();
        static MultistageFanoutMonitor #(T, I) monitor = new(monitor_out_broadcast, bfm);


        ////////////////////////////////////////////////////////////////
        // scoreboard
        static TriggerableQueue #(T) scoreboard_in_queue_dut = new();
        static TriggerableQueue #(T) scoreboard_in_queue_golden = new();
        static MultistageFanoutScoreboard #(T) scoreboard = new(scoreboard_in_queue_dut, scoreboard_in_queue_golden);

        ////////////////////////////////////////////////////////////////
        // watch dog

        ////////////////////////////////////////////////////////////////
        // Queue Linkage
        generator_out_broadcast.add_queue(driver_in_queue);
        generator_out_broadcast.add_queue(golden_in_queue);
        monitor_out_broadcast.add_queue(scoreboard_in_queue_dut);
        golden_out_broadcast.add_queue(scoreboard_in_queue_golden);

        ////////////////////////////////////////////////////////////////
        // Set up dump 
        $dumpfile("waves.vcd");
        $dumpvars(0, multistage_fanout_tb);

        ////////////////////////////////////////////////////////////////
        // Reset logic
        bfm.valid_i <= 0;
        rst <= 0;
        repeat(5) @(posedge clk)
        rst <= 1;
        repeat(7) @(posedge clk)
        rst <= 0;
        // Run
        fork
            generator.run();
            driver.run();
            golden.run();
            monitor.run();
            scoreboard.run();
            //watchdog.run();
        join_none

        #1000000;
        $finish;
    end



endmodule