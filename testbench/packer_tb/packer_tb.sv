////////////////////////////////////////////////////////////////
// rtl utilities include and imports
`include "rtl_utilities_pkg.sv"
import constant_functions_pkg::*;

////////////////////////////////////////////////////////////////
// interface include
`include "packer_inf.svh"

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
`include "fsm/fsm_strider_ohe/fsm_strider_ohe.sv"
`include "processing_elements/packer/packer.sv"

////////////////////////////////////////////////////////////////
// timescale
`timescale 1ns / 1ns

module packer_tb #(
    parameter REGISTERED_IN = 1,
    parameter DATA_WIDTH = 8,
    parameter INGRESS_SIZE = 2,
    parameter EGRESS_SIZE = 8
) ();

    localparam real CLK_PERIOD = 10;

    localparam type T = PackerIO #(
        .REGISTERED_IN(REGISTERED_IN),
        .DATA_WIDTH(DATA_WIDTH),
        .INGRESS_SIZE(INGRESS_SIZE),
        .EGRESS_SIZE(EGRESS_SIZE)
    );

    localparam type I = virtual packer_inf #(
        .REGISTERED_IN(REGISTERED_IN),
        .DATA_WIDTH(DATA_WIDTH),
        .INGRESS_SIZE(INGRESS_SIZE),
        .EGRESS_SIZE(EGRESS_SIZE)
    );

    logic clk = 0;
    always begin #(CLK_PERIOD / 2); clk = ~clk; end

    packer_inf #(
        .REGISTERED_IN(REGISTERED_IN),
        .DATA_WIDTH(DATA_WIDTH),
        .INGRESS_SIZE(INGRESS_SIZE),
        .EGRESS_SIZE(EGRESS_SIZE)
    ) bfm (.clk_i(clk));

    packer #(
        .REGISTERED_IN(REGISTERED_IN),
        .DATA_WIDTH(DATA_WIDTH),
        .INGRESS_SIZE(INGRESS_SIZE),
        .EGRESS_SIZE(EGRESS_SIZE)
    ) dut (
        .clk_i(clk),
        .unpacked_i(bfm.unpacked_i),
        .sync_i(bfm.sync_i),
        .packed_o(bfm.packed_o),
        .packer_valid_o(bfm.packer_valid_o)
    );

    initial begin
        static TriggerableQueueBroadcaster #(T) dut_generator_out_broadcast = new();
        static PackerGenerator #(T) dut_generator = new(dut_generator_out_broadcast);

        static TriggerableQueueBroadcaster #(T) model_generator_out_broadcast = new();
        static PackerGenerator #(T) model_generator = new(model_generator_out_broadcast);

        static TriggerableQueue #(T) driver_in_queue = new();
        static PackerDriver #(T, I) driver = new(driver_in_queue, bfm);

        static TriggerableQueue #(T) golden_in_queue = new();
        static TriggerableQueueBroadcaster #(T) golden_out_broadcast = new();
        static PackerModel #(T) golden = new(golden_in_queue, golden_out_broadcast);

        static TriggerableQueueBroadcaster #(T) monitor_out_broadcast = new();
        static PackerMonitor #(T, I) monitor = new(monitor_out_broadcast, bfm);

        static TriggerableQueue #(T) scoreboard_in_queue_dut = new();
        static TriggerableQueue #(T) scoreboard_in_queue_golden = new();
        static PackerScoreboard #(T) scoreboard = new(scoreboard_in_queue_dut, scoreboard_in_queue_golden);

        dut_generator_out_broadcast.add_queue(driver_in_queue);
        model_generator_out_broadcast.add_queue(golden_in_queue);
        monitor_out_broadcast.add_queue(scoreboard_in_queue_dut);
        golden_out_broadcast.add_queue(scoreboard_in_queue_golden);

        $dumpfile("waves.vcd");
        $dumpvars(0, packer_tb);

        bfm.unpacked_i = '0;
        bfm.sync_i = 0;
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

        #10000;
        $error("Packer testbench timed out");
        $finish;
    end
endmodule
