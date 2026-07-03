////////////////////////////////////////////////////////////////
// rtl utilities include and imports
`include "rtl_utilities_pkg.sv"
import constant_functions_pkg::*;

////////////////////////////////////////////////////////////////
// interface include 
`include "multistage_mux_inf.svh"

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
`include "processing_elements/multistage_mux/multistage_mux.sv"

////////////////////////////////////////////////////////////////
// timescale 
`timescale 1ns / 1ns

module multistage_mux_tb #(
    parameter DATA_WIDTH = 12,
    parameter SIZE = 17,
    parameter REGISTERED_IN = 0,
    parameter LUTX = 4,
    parameter GRADE = 2
) ();

    ////////////////////////////////////////////////////////////////
    // localparams

    localparam real CLK_PERIOD = 10;

    localparam type T = MultistageMuxIO #(
        .DATA_WIDTH(DATA_WIDTH),
        .SIZE(SIZE),
        .REGISTERED_IN(REGISTERED_IN),
        .LUTX(LUTX),
        .GRADE(GRADE)
    );

    localparam type I = virtual multistage_mux_inf #(
        .DATA_WIDTH(DATA_WIDTH),
        .SIZE(SIZE),
        .REGISTERED_IN(REGISTERED_IN),
        .LUTX(LUTX),
        .GRADE(GRADE)
    );

    ////////////////////////////////////////////////////////////////
    // clock generation
    logic clk = 0;
    always begin #(CLK_PERIOD/2); clk = ~clk; end

    ////////////////////////////////////////////////////////////////
    // interface
    multistage_mux_inf #(
        .DATA_WIDTH(DATA_WIDTH),
        .SIZE(SIZE),
        .REGISTERED_IN(REGISTERED_IN),
        .LUTX(LUTX),
        .GRADE(GRADE)
    ) bfm (.clk_i(clk)); // bfm, "bus functional model"
    
    ////////////////////////////////////////////////////////////////
    // DUT
    multistage_mux #(
        .DATA_WIDTH(DATA_WIDTH),
        .SIZE(SIZE),
        .REGISTERED_IN(REGISTERED_IN),
        .LUTX(LUTX),
        .GRADE(GRADE)
    ) dut (
        .clk_i(clk),

        .data_i(bfm.data_i),
        .sel_i(bfm.sel_i),

        .data_o(bfm.data_o)
    );

    initial begin
        ////////////////////////////////////////////////////////////////
        // generator
        static TriggerableQueueBroadcaster #(T) dut_generator_out_broadcast = new();
        static MultistageMuxGenerator #(T) dut_generator = new(dut_generator_out_broadcast);

        static TriggerableQueueBroadcaster #(T) model_generator_out_broadcast = new();
        static MultistageMuxGenerator #(T) model_generator = new(model_generator_out_broadcast);

        ////////////////////////////////////////////////////////////////
        // driver
        static TriggerableQueue #(T) driver_in_queue = new();
        static MultistageMuxDriver #(T,I) driver = new(driver_in_queue, bfm);

        ////////////////////////////////////////////////////////////////
        // golden model
        static TriggerableQueue #(T) golden_in_queue = new();
        static TriggerableQueueBroadcaster #(T) golden_out_broadcast = new();
        static MultistageMuxModel #(T) golden = new(golden_in_queue, golden_out_broadcast);

        ////////////////////////////////////////////////////////////////
        // monitor
        static TriggerableQueueBroadcaster #(T) monitor_out_broadcast = new();
        static MultistageMuxMonitor #(T, I) monitor = new(monitor_out_broadcast, bfm);

        ////////////////////////////////////////////////////////////////
        // scoreboard
        static TriggerableQueue #(T) scoreboard_in_queue_dut = new();
        static TriggerableQueue #(T) scoreboard_in_queue_golden = new();
        static MultistageMuxScoreboard #(T) scoreboard = new(scoreboard_in_queue_dut, scoreboard_in_queue_golden);

        ////////////////////////////////////////////////////////////////
        // Queue Linkage
        dut_generator_out_broadcast.add_queue(driver_in_queue);
        model_generator_out_broadcast.add_queue(golden_in_queue);
        monitor_out_broadcast.add_queue(scoreboard_in_queue_dut);
        golden_out_broadcast.add_queue(scoreboard_in_queue_golden);

        ////////////////////////////////////////////////////////////////
        // Set up dump 
        $dumpfile("waves.vcd");
        $dumpvars(0, multistage_mux_tb);
        

        ////////////////////////////////////////////////////////////////
        // Reset logic
        bfm.idle = 1;
        @(posedge clk) // clean start just after posedge

        // Run
        fork
            dut_generator.run();
            model_generator.run();
            driver.run();
            golden.run();
            monitor.run();
            scoreboard.run();
        join_none

        #1000;
        $error("Testbench calling $finish");
        $finish;
        
    end
endmodule
