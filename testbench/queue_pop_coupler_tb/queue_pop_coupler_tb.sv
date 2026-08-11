////////////////////////////////////////////////////////////////
// rtl utilities include and imports
`include "rtl_utilities_pkg.sv"
import constant_functions_pkg::*;

////////////////////////////////////////////////////////////////
// interface include
`include "queue_pop_coupler_inf.svh"

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
`include "memory_systems/queue_pop_coupler/queue_pop_coupler.sv"

`timescale 1ns / 1ns

module queue_pop_coupler_tb #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 4,
    parameter ASYNC = 0,
    parameter BURSTMARK = 4,
    parameter CONFLICT_PROOF = 1,
    parameter REGISTERED_IN = 1,
    parameter REGISTERED_IN_BRAM = 1,
    parameter REGISTERED_OUT_BRAM = 1
) ();
    localparam real CLK_PERIOD = 10;

    localparam type T = QueuePopCouplerIO #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .ASYNC(ASYNC),
        .BURSTMARK(BURSTMARK),
        .CONFLICT_PROOF(CONFLICT_PROOF),
        .REGISTERED_IN(REGISTERED_IN),
        .REGISTERED_IN_BRAM(REGISTERED_IN_BRAM),
        .REGISTERED_OUT_BRAM(REGISTERED_OUT_BRAM)
    );

    localparam type I = virtual queue_pop_coupler_inf #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .ASYNC(ASYNC),
        .BURSTMARK(BURSTMARK),
        .CONFLICT_PROOF(CONFLICT_PROOF),
        .REGISTERED_IN(REGISTERED_IN),
        .REGISTERED_IN_BRAM(REGISTERED_IN_BRAM),
        .REGISTERED_OUT_BRAM(REGISTERED_OUT_BRAM)
    );

    logic clk = 0;
    always begin #(CLK_PERIOD / 2); clk = ~clk; end

    queue_pop_coupler_inf #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .ASYNC(ASYNC),
        .BURSTMARK(BURSTMARK),
        .CONFLICT_PROOF(CONFLICT_PROOF),
        .REGISTERED_IN(REGISTERED_IN),
        .REGISTERED_IN_BRAM(REGISTERED_IN_BRAM),
        .REGISTERED_OUT_BRAM(REGISTERED_OUT_BRAM)
    ) bfm (.rd_clk_i(clk));

    queue_pop_coupler #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .ASYNC(ASYNC),
        .BURSTMARK(BURSTMARK),
        .CONFLICT_PROOF(CONFLICT_PROOF),
        .REGISTERED_IN(REGISTERED_IN),
        .REGISTERED_IN_BRAM(REGISTERED_IN_BRAM),
        .REGISTERED_OUT_BRAM(REGISTERED_OUT_BRAM)
    ) dut (
        .rd_clk_i(clk),
        .rd_rst_i(bfm.rd_rst_i),

        .empty_i(bfm.empty_i),
        .lookahead_i(bfm.lookahead_i),
        .rd_data_i(bfm.rd_data_i),
        .rd_valid_i(bfm.rd_valid_i),
        .pop_o(bfm.pop_o),
        .less_than_or_eq_o(bfm.less_than_or_eq_o),

        .rd_data_o(bfm.rd_data_o),
        .rd_valid_o(bfm.rd_valid_o),
        .burstvalid_o(bfm.burstvalid_o),
        .ready_i(bfm.ready_i)
    );

    initial begin
        static TriggerableQueueBroadcaster #(T) dut_generator_out_broadcast = new();
        static QueuePopCouplerGenerator #(T) dut_generator =
            new(dut_generator_out_broadcast);

        static TriggerableQueueBroadcaster #(T) model_generator_out_broadcast = new();
        static QueuePopCouplerGenerator #(T) model_generator =
            new(model_generator_out_broadcast);

        static TriggerableQueue #(T) driver_in_queue = new();
        static QueuePopCouplerDriver #(T, I) driver = new(driver_in_queue, bfm);

        static TriggerableQueue #(T) golden_in_queue = new();
        static TriggerableQueueBroadcaster #(T) golden_out_broadcast = new();
        static QueuePopCouplerModel #(T) golden =
            new(golden_in_queue, golden_out_broadcast);

        static TriggerableQueueBroadcaster #(T) monitor_out_broadcast = new();
        static QueuePopCouplerMonitor #(T, I) monitor =
            new(monitor_out_broadcast, bfm);

        static TriggerableQueue #(T) scoreboard_in_queue_dut = new();
        static TriggerableQueue #(T) scoreboard_in_queue_golden = new();
        static QueuePopCouplerScoreboard #(T) scoreboard = new(
            scoreboard_in_queue_dut,
            scoreboard_in_queue_golden
        );

        dut_generator_out_broadcast.add_queue(driver_in_queue);
        model_generator_out_broadcast.add_queue(golden_in_queue);
        monitor_out_broadcast.add_queue(scoreboard_in_queue_dut);
        golden_out_broadcast.add_queue(scoreboard_in_queue_golden);

        $dumpfile("waves.vcd");
        $dumpvars(0, queue_pop_coupler_tb);

        bfm.rd_rst_i = 0;
        bfm.empty_i = 1;
        bfm.lookahead_i = 1;
        bfm.rd_data_i = '0;
        bfm.rd_valid_i = 0;
        bfm.ready_i = 0;
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
        $fatal(1, "QueuePopCoupler testbench timeout");
    end
endmodule
