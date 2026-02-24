////////////////////////////////////////////////////////////////
// interface include 
`include "example_inf.svh"

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
// RTL includes, for this example we will simplify define it here
// but normally RTL willl be in a separate 'rtl' folder outside of the
// testbench folder.

//`include "example_adder.sv"

module example_adder #(
    parameter DATA_WIDTH
)  (
    input clk_i,
    input rst_i,

    input  [DATA_WIDTH - 1 : 0] a_i,
    input  valid_i,

    output [DATA_WIDTH - 1 : 0] d_o,
    output valid_o
); 
    logic [DATA_WIDTH - 1 : 0] a;
    logic                      valid;

    always@(posedge clk_i) begin
        a     <= a_i;
        valid <= valid_i;
    end

    assign d_o     = a + 1;
    assign valid_o = valid;

endmodule

////////////////////////////////////////////////////////////////
// timescale 
`timescale 1ns / 1ns

module example_tb();

    ////////////////////////////////////////////////////////////////
    // localparams
    localparam DATA_WIDTH = 8;
    localparam real CLK_PERIOD = 10;

    localparam type T = ExampleClass #(
        .DATA_WIDTH(DATA_WIDTH)
    );

    localparam type I = virtual example_inf #(
        .DATA_WIDTH(DATA_WIDTH)
    );

    ////////////////////////////////////////////////////////////////
    // clock generation and reset
    logic clk = 0;
    logic rst = 0;
    always begin #(CLK_PERIOD/2); clk = ~clk; end

    ////////////////////////////////////////////////////////////////
    // interface
    example_inf #(
        .DATA_WIDTH(DATA_WIDTH)
    ) bfm (.clk_i(clk), .rst_i(rst)); // bfm, "bus functional model"
    
    ////////////////////////////////////////////////////////////////
    // DUT
    example_adder #(
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk_i(clk),
        .rst_i(rst),

        .a_i(bfm.a_i),
        .valid_i(bfm.valid_i),

        .d_o(bfm.d_o),
        .valid_o(bfm.valid_o)
    );

    initial begin
        ////////////////////////////////////////////////////////////////
        // generator
        static TriggerableQueueBroadcaster #(T) generator_out_broadcast = new();
        static ExampleGenerator #(T) generator = new(generator_out_broadcast);

        ////////////////////////////////////////////////////////////////
        // driver
        static TriggerableQueue #(T) driver_in_queue = new();
        static ExampleDriver #(T, I) driver = new(driver_in_queue, bfm);

        ////////////////////////////////////////////////////////////////
        // golden model
        static TriggerableQueue #(T) golden_in_queue = new();
        static TriggerableQueueBroadcaster #(T) golden_out_broadcast = new();
        static ExampleModel #(T) golden = new(golden_in_queue, golden_out_broadcast);

        ////////////////////////////////////////////////////////////////
        // monitor
        static TriggerableQueueBroadcaster #(T) monitor_out_broadcast = new();
        static ExampleMonitor #(T, I) monitor = new(monitor_out_broadcast, bfm);


        ////////////////////////////////////////////////////////////////
        // scoreboard
        static TriggerableQueue #(T) scoreboard_in_queue_dut = new();
        static TriggerableQueue #(T) scoreboard_in_queue_golden = new();
        static ExampleScoreboard #(T) scoreboard = new(scoreboard_in_queue_dut, scoreboard_in_queue_golden);

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
        $dumpvars(0, example_tb);

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