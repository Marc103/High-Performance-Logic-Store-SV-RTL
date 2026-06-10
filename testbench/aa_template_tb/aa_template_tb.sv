////////////////////////////////////////////////////////////////
// rtl utilities include and imports
`include "rtl_utilities_pkg.sv"
import constant_functions_pkg::*;

////////////////////////////////////////////////////////////////
// interface include 
`include "???_inf.svh"

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
`include "???.sv"

////////////////////////////////////////////////////////////////
// timescale 
`timescale 1ns / 1ns

module ???_tb();

    ////////////////////////////////////////////////////////////////
    // localparams
    ???

    localparam real CLK_PERIOD = 10;

    localparam type T = ???IO #(
        ???
    );

    localparam type I = virtual ???_inf #(
        ???
    );

    ////////////////////////////////////////////////////////////////
    // clock generation and reset
    logic clk = 0;
    logic rst = 0;
    always begin #(CLK_PERIOD/2); clk = ~clk; end

    ////////////////////////////////////////////////////////////////
    // interface
    ???_inf #(
        ???
    ) bfm (???); // bfm, "bus functional model"
    
    ////////////////////////////////////////////////////////////////
    // DUT
    ??? #(
        ???
    ) dut (
        ???
    );

    initial begin
        ////////////////////////////////////////////////////////////////
        // generator
        static TriggerableQueueBroadcaster #(T) dut_generator_out_broadcast = new();
        static ???Generator #(T) dut_generator = new(dut_generator_out_broadcast);

        static TriggerableQueueBroadcaster #(T) model_generator_out_broadcast = new();
        static ???Generator #(T) model_generator = new(model_generator_out_broadcast);

        ////////////////////////////////////////////////////////////////
        // driver
        static TriggerableQueue #(T) driver_in_queue = new();
        static ???Driver #(T,I) driver = new(driver_in_queue, bfm);

        ////////////////////////////////////////////////////////////////
        // golden model
        static TriggerableQueue #(T) golden_in_queue = new();
        static TriggerableQueueBroadcaster #(T) golden_out_broadcast = new();
        static ???Model #(T) golden = new(golden_in_queue, golden_out_broadcast);

        ////////////////////////////////////////////////////////////////
        // monitor
        static TriggerableQueueBroadcaster #(T) monitor_out_broadcast = new();
        static ???Monitor #(T, I) monitor = new(monitor_out_broadcast, bfm);

        ////////////////////////////////////////////////////////////////
        // scoreboard
        static TriggerableQueue #(T) scoreboard_in_queue_dut = new();
        static TriggerableQueue #(T) scoreboard_in_queue_golden = new();
        static ???Scoreboard #(T) scoreboard = new(scoreboard_in_queue_dut, scoreboard_in_queue_golden);

        ////////////////////////////////////////////////////////////////
        // Queue Linkage
        dut_generator_out_broadcast.add_queue(driver_in_queue);
        model_generator_out_broadcast.add_queue(golden_in_queue);
        monitor_out_broadcast.add_queue(scoreboard_in_queue_dut);
        golden_out_broadcast.add_queue(scoreboard_in_queue_golden);

        ////////////////////////////////////////////////////////////////
        // Set up dump 
        $dumpfile("waves.vcd");
        $dumpvars(0, ???_tb);
        

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
