////////////////////////////////////////////////////////////////
// rtl utilities include and imports
`include "rtl_utilities_pkg.sv"
import constant_functions_pkg::*;

////////////////////////////////////////////////////////////////
// interface include 
`include "priority_encoder_inf.svh"

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
`include "io_circuits/pipe/pipe.sv"
`include "processing_elements/max/max.sv"
`include "processing_elements/priority_encoder/priority_encoder.sv"

////////////////////////////////////////////////////////////////
// timescale 
`timescale 1ns / 1ns

module priority_encoder_tb #(
    parameter INPUT_DATA_WIDTH = 17,
    parameter REGISTERED_IN = 1,
    parameter LUTX = 4,
    parameter GRADE = 1
) ();

    ////////////////////////////////////////////////////////////////
    // localparams
    localparam real CLK_PERIOD = 10;

    localparam type T = PriorityEncoderIO #(
        .INPUT_DATA_WIDTH(INPUT_DATA_WIDTH),
        .REGISTERED_IN(REGISTERED_IN),
        .LUTX(LUTX),
        .GRADE(GRADE)
    );

    localparam type I = virtual priority_encoder_inf #(
        .INPUT_DATA_WIDTH(INPUT_DATA_WIDTH),
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
    priority_encoder_inf #(
        .INPUT_DATA_WIDTH(INPUT_DATA_WIDTH),
        .REGISTERED_IN(REGISTERED_IN),
        .LUTX(LUTX),
        .GRADE(GRADE)
    ) bfm (.clk_i(clk)); // bfm, "bus functional model"
    
    ////////////////////////////////////////////////////////////////
    // DUT
    priority_encoder #(
        .INPUT_DATA_WIDTH(INPUT_DATA_WIDTH),
        .REGISTERED_IN(REGISTERED_IN),
        .LUTX(LUTX),
        .GRADE(GRADE)
    ) dut (
        .clk_i(clk),

        .priority_i(bfm.priority_i),

        .priority_encoded_o(bfm.priority_encoded_o)
    );

    initial begin
        ////////////////////////////////////////////////////////////////
        // generator
        static TriggerableQueueBroadcaster #(T) dut_generator_out_broadcast = new();
        static PriorityEncoderGenerator #(T) dut_generator = new(dut_generator_out_broadcast);

        static TriggerableQueueBroadcaster #(T) model_generator_out_broadcast = new();
        static PriorityEncoderGenerator #(T) model_generator = new(model_generator_out_broadcast);

        ////////////////////////////////////////////////////////////////
        // driver
        static TriggerableQueue #(T) driver_in_queue = new();
        static PriorityEncoderDriver #(T,I) driver = new(driver_in_queue, bfm);

        ////////////////////////////////////////////////////////////////
        // golden model
        static TriggerableQueue #(T) golden_in_queue = new();
        static TriggerableQueueBroadcaster #(T) golden_out_broadcast = new();
        static PriorityEncoderModel #(T) golden = new(golden_in_queue, golden_out_broadcast);

        ////////////////////////////////////////////////////////////////
        // monitor
        static TriggerableQueueBroadcaster #(T) monitor_out_broadcast = new();
        static PriorityEncoderMonitor #(T, I) monitor = new(monitor_out_broadcast, bfm);

        ////////////////////////////////////////////////////////////////
        // scoreboard
        static TriggerableQueue #(T) scoreboard_in_queue_dut = new();
        static TriggerableQueue #(T) scoreboard_in_queue_golden = new();
        static PriorityEncoderScoreboard #(T) scoreboard = new(scoreboard_in_queue_dut, scoreboard_in_queue_golden);

        ////////////////////////////////////////////////////////////////
        // Queue Linkage
        dut_generator_out_broadcast.add_queue(driver_in_queue);
        model_generator_out_broadcast.add_queue(golden_in_queue);
        monitor_out_broadcast.add_queue(scoreboard_in_queue_dut);
        golden_out_broadcast.add_queue(scoreboard_in_queue_golden);

        ////////////////////////////////////////////////////////////////
        // Set up dump 
        $dumpfile("waves.vcd");
        $dumpvars(0, priority_encoder_tb);

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

        #5000;
        $error("Testbench calling $finish");
        $finish;
        
    end
endmodule
