////////////////////////////////////////////////////////////////
// rtl utilities include and imports
`include "rtl_utilities_pkg.sv"
import constant_functions_pkg::*;

////////////////////////////////////////////////////////////////
// interface include 
`include "reduction_tree_inf.svh"

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
`include "processing_elements/reduction_tree/reduction_tree.sv"

////////////////////////////////////////////////////////////////
// timescale 
`timescale 1ns / 1ns

module reduction_tree_tb #(
    parameter DATA_WIDTH = 8,
    parameter GATE = 0,
    parameter REGISTERED_IN = 1,
    parameter LUTX = 4,
    parameter GRADE = 1
) ();

    ////////////////////////////////////////////////////////////////
    // localparams
    localparam real CLK_PERIOD = 10;

    localparam type T = ReductionTreeIO #(
        .DATA_WIDTH(DATA_WIDTH),
        .GATE(GATE),
        .REGISTERED_IN(REGISTERED_IN),
        .LUTX(LUTX),
        .GRADE(GRADE)
    );

    localparam type I = virtual reduction_tree_inf #(
        .DATA_WIDTH(DATA_WIDTH),
        .GATE(GATE),
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
    reduction_tree_inf #(
        .DATA_WIDTH(DATA_WIDTH),
        .GATE(GATE),
        .REGISTERED_IN(REGISTERED_IN),
        .LUTX(LUTX),
        .GRADE(GRADE)
    ) bfm (.clk_i(clk)); // bfm, "bus functional model"
    
    ////////////////////////////////////////////////////////////////
    // DUT
    reduction_tree #(
        .DATA_WIDTH(DATA_WIDTH),
        .GATE(GATE),
        .REGISTERED_IN(REGISTERED_IN),
        .LUTX(LUTX),
        .GRADE(GRADE)
    ) dut (
        .clk_i(clk),
        .data_i(bfm.data_i),
        .reduced_o(bfm.reduced_o)
    );

    initial begin
        ////////////////////////////////////////////////////////////////
        // generator
        static TriggerableQueueBroadcaster #(T) dut_generator_out_broadcast = new();
        static ReductionTreeGenerator #(T) dut_generator = new(dut_generator_out_broadcast);

        static TriggerableQueueBroadcaster #(T) model_generator_out_broadcast = new();
        static ReductionTreeGenerator #(T) model_generator = new(model_generator_out_broadcast);

        ////////////////////////////////////////////////////////////////
        // driver
        static TriggerableQueue #(T) driver_in_queue = new();
        static ReductionTreeDriver #(T,I) driver = new(driver_in_queue, bfm);

        ////////////////////////////////////////////////////////////////
        // golden model
        static TriggerableQueue #(T) golden_in_queue = new();
        static TriggerableQueueBroadcaster #(T) golden_out_broadcast = new();
        static ReductionTreeModel #(T) golden = new(golden_in_queue, golden_out_broadcast);

        ////////////////////////////////////////////////////////////////
        // monitor
        static TriggerableQueueBroadcaster #(T) monitor_out_broadcast = new();
        static ReductionTreeMonitor #(T, I) monitor = new(monitor_out_broadcast, bfm);

        ////////////////////////////////////////////////////////////////
        // scoreboard
        static TriggerableQueue #(T) scoreboard_in_queue_dut = new();
        static TriggerableQueue #(T) scoreboard_in_queue_golden = new();
        static ReductionTreeScoreboard #(T) scoreboard = new(scoreboard_in_queue_dut, scoreboard_in_queue_golden);

        ////////////////////////////////////////////////////////////////
        // Queue Linkage
        dut_generator_out_broadcast.add_queue(driver_in_queue);
        model_generator_out_broadcast.add_queue(golden_in_queue);
        monitor_out_broadcast.add_queue(scoreboard_in_queue_dut);
        golden_out_broadcast.add_queue(scoreboard_in_queue_golden);

        ////////////////////////////////////////////////////////////////
        // Set up dump 
        $dumpfile("waves.vcd");
        $dumpvars(0, reduction_tree_tb);

        ////////////////////////////////////////////////////////////////
        // Run
        bfm.idle = 1;
        @(posedge clk) // clean start just after posedge

        fork
            dut_generator.run();
            model_generator.run();
            driver.run();
            golden.run();
            monitor.run();
            scoreboard.run();
        join_none

        #1000;
        $display("Testbench called $finish;");
        $finish;
        
    end
endmodule
