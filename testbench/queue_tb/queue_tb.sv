////////////////////////////////////////////////////////////////
// rtl utilities include and imports
`include "rtl_utilities_pkg.sv"
import constant_functions_pkg::*;

////////////////////////////////////////////////////////////////
// interface include 
`include "queue_inf.svh"

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
`include "memory_systems/bram_dual_port_simple/bram_dual_port_simple.sv"
`include "memory_systems/queue/queue.sv"

////////////////////////////////////////////////////////////////
// timescale 
`timescale 1ns / 1ns

module queue_tb #(
    parameter ADDR_WIDTH = 3,
    parameter DATA_WIDTH = 16,
    parameter CONFLICT_PROOF = 1,
    parameter REGISTERED_IN = 1,
    parameter REGISTERED_IN_BRAM = 1,
    parameter REGISTERED_OUT_BRAM = 1,
    parameter NUMBER_OF_QUEUES = 3
) ();

    ////////////////////////////////////////////////////////////////
    // localparams
    localparam real CLK_PERIOD = 10;

    localparam type T = QueueIO #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .CONFLICT_PROOF(CONFLICT_PROOF),
        .REGISTERED_IN(REGISTERED_IN),
        .REGISTERED_IN_BRAM(REGISTERED_IN_BRAM),
        .REGISTERED_OUT_BRAM(REGISTERED_OUT_BRAM),
        .NUMBER_OF_QUEUES(NUMBER_OF_QUEUES)
    );

    localparam type I = virtual queue_inf #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .CONFLICT_PROOF(CONFLICT_PROOF),
        .REGISTERED_IN(REGISTERED_IN),
        .REGISTERED_IN_BRAM(REGISTERED_IN_BRAM),
        .REGISTERED_OUT_BRAM(REGISTERED_OUT_BRAM),
        .NUMBER_OF_QUEUES(NUMBER_OF_QUEUES)
    );

    ////////////////////////////////////////////////////////////////
    // clock generatioN
    logic clk = 0;
    always begin #(CLK_PERIOD/2); clk = ~clk; end

    ////////////////////////////////////////////////////////////////
    // interface
    queue_inf #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .CONFLICT_PROOF(CONFLICT_PROOF),
        .REGISTERED_IN(REGISTERED_IN),
        .REGISTERED_IN_BRAM(REGISTERED_IN_BRAM),
        .REGISTERED_OUT_BRAM(REGISTERED_OUT_BRAM),
        .NUMBER_OF_QUEUES(NUMBER_OF_QUEUES)
    ) bfm (.clk_i(clk)); // bfm, "bus functional model"
    
    ////////////////////////////////////////////////////////////////
    // DUT
    queue #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .CONFLICT_PROOF(CONFLICT_PROOF),
        .REGISTERED_IN(REGISTERED_IN),
        .REGISTERED_IN_BRAM(REGISTERED_IN_BRAM),
        .REGISTERED_OUT_BRAM(REGISTERED_OUT_BRAM),
        .NUMBER_OF_QUEUES(NUMBER_OF_QUEUES)
    ) dut (
        .clk_i(clk),

        .rst_i(bfm.rst_i),

        .push_i(bfm.push_i),
        .wr_data_i(bfm.wr_data_i),

        .pop_i(bfm.pop_i),
        .rd_data_o(bfm.rd_data_o),
        
        .full_o(bfm.full_o),
        .empty_o(bfm.empty_o),

        .less_than_i(bfm.less_than_i),
        .less_than_o(bfm.less_than_o),

        .more_than_i(bfm.more_than_i),
        .more_than_o(bfm.more_than_o)
    );

    initial begin
        ////////////////////////////////////////////////////////////////
        // generator
        static TriggerableQueueBroadcaster #(T) dut_generator_out_broadcast = new();
        static QueueGenerator #(T) dut_generator = new(dut_generator_out_broadcast);

        static TriggerableQueueBroadcaster #(T) model_generator_out_broadcast = new();
        static QueueGenerator #(T) model_generator = new(model_generator_out_broadcast);

        ////////////////////////////////////////////////////////////////
        // driver
        static TriggerableQueue #(T) driver_in_queue = new();
        static QueueDriver #(T,I) driver = new(driver_in_queue, bfm);

        ////////////////////////////////////////////////////////////////
        // golden model
        static TriggerableQueue #(T) golden_in_queue = new();
        static TriggerableQueueBroadcaster #(T) golden_out_broadcast = new();
        static QueueModel #(T) golden = new(golden_in_queue, golden_out_broadcast);

        ////////////////////////////////////////////////////////////////
        // monitor
        static TriggerableQueueBroadcaster #(T) monitor_out_broadcast = new();
        static QueueMonitor #(T, I) monitor = new(monitor_out_broadcast, bfm);

        ////////////////////////////////////////////////////////////////
        // scoreboard
        static TriggerableQueue #(T) scoreboard_in_queue_dut = new();
        static TriggerableQueue #(T) scoreboard_in_queue_golden = new();
        static QueueScoreboard #(T) scoreboard = new(scoreboard_in_queue_dut, scoreboard_in_queue_golden);

        ////////////////////////////////////////////////////////////////
        // Queue Linkage
        dut_generator_out_broadcast.add_queue(driver_in_queue);
        model_generator_out_broadcast.add_queue(golden_in_queue);
        monitor_out_broadcast.add_queue(scoreboard_in_queue_dut);
        golden_out_broadcast.add_queue(scoreboard_in_queue_golden);

        ////////////////////////////////////////////////////////////////
        // Set up dump 
        $dumpfile("waves.vcd");
        $dumpvars(0, queue_tb);

        ////////////////////////////////////////////////////////////////
        // Run
        bfm.idle <= 1;
        @(posedge clk) // clean start just after posedge

        // Run
        fork
            dut_generator.run();
            model_generator.run();
            driver.run();
            golden.run();
            monitor.run();
            scoreboard.run();
            //watchdog.run();
        join_none

        #10000;
        $display("Testbench called $finish;");
        $finish;
    end
endmodule
