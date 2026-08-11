////////////////////////////////////////////////////////////////
// rtl utilities include and imports
`include "rtl_utilities_pkg.sv"
import constant_functions_pkg::*;

////////////////////////////////////////////////////////////////
// interface include
`include "queue_carriage_inf.svh"

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
`include "memory_systems/bram_dual_port_simple/bram_dual_port_simple.sv"
`include "memory_systems/queue/queue.sv"
`include "memory_systems/async_fifo/sync_ptr.v"
`include "memory_systems/async_fifo/wptr_full.v"
`include "memory_systems/async_fifo/rptr_empty.v"
`include "memory_systems/async_fifo/fifomem.v"
`include "memory_systems/async_fifo/async_fifo.v"
`include "memory_systems/queue_async/queue_async.sv"
`include "memory_systems/queue_push_coupler/queue_push_coupler.sv"
`include "memory_systems/queue_pop_coupler/queue_pop_coupler.sv"
`include "memory_systems/queue_carriage/queue_carriage.sv"

////////////////////////////////////////////////////////////////
// timescale
`timescale 1ns / 1ns

module queue_carriage_tb #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 4,
    parameter ASYNC = 0,
    parameter PUSH_SIMPLE = 0,
    parameter PUSH_BURST_SIZE = 4,
    parameter POP_BURSTMARK = 4,
    parameter CONFLICT_PROOF = 1,
    parameter REGISTERED_IN = 1,
    parameter REGISTERED_IN_BRAM = 1,
    parameter REGISTERED_OUT_BRAM = 1,
    parameter SYNC_STAGES = 2
) ();
    localparam real WR_CLK_PERIOD = 10;
    localparam real RD_CLK_PERIOD = 14;

    localparam type T = QueueCarriageIO #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .ASYNC(ASYNC),
        .PUSH_SIMPLE(PUSH_SIMPLE),
        .PUSH_BURST_SIZE(PUSH_BURST_SIZE),
        .POP_BURSTMARK(POP_BURSTMARK),
        .CONFLICT_PROOF(CONFLICT_PROOF),
        .REGISTERED_IN(REGISTERED_IN),
        .REGISTERED_IN_BRAM(REGISTERED_IN_BRAM),
        .REGISTERED_OUT_BRAM(REGISTERED_OUT_BRAM),
        .SYNC_STAGES(SYNC_STAGES)
    );

    localparam type I = virtual queue_carriage_inf #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .ASYNC(ASYNC),
        .PUSH_SIMPLE(PUSH_SIMPLE),
        .PUSH_BURST_SIZE(PUSH_BURST_SIZE),
        .POP_BURSTMARK(POP_BURSTMARK),
        .CONFLICT_PROOF(CONFLICT_PROOF),
        .REGISTERED_IN(REGISTERED_IN),
        .REGISTERED_IN_BRAM(REGISTERED_IN_BRAM),
        .REGISTERED_OUT_BRAM(REGISTERED_OUT_BRAM),
        .SYNC_STAGES(SYNC_STAGES)
    );

    logic wr_clk = 0;
    logic rd_clk_async = 0;
    wire rd_clk;
    always begin #(WR_CLK_PERIOD / 2); wr_clk = ~wr_clk; end

    generate
        if(ASYNC == 1) begin : asynchronous_read_clock_g
            always begin #(RD_CLK_PERIOD / 2); rd_clk_async = ~rd_clk_async; end
            assign rd_clk = rd_clk_async;
        end else begin : synchronous_read_clock_g
            assign rd_clk = wr_clk;
        end
    endgenerate

    queue_carriage_inf #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .ASYNC(ASYNC),
        .PUSH_SIMPLE(PUSH_SIMPLE),
        .PUSH_BURST_SIZE(PUSH_BURST_SIZE),
        .POP_BURSTMARK(POP_BURSTMARK),
        .CONFLICT_PROOF(CONFLICT_PROOF),
        .REGISTERED_IN(REGISTERED_IN),
        .REGISTERED_IN_BRAM(REGISTERED_IN_BRAM),
        .REGISTERED_OUT_BRAM(REGISTERED_OUT_BRAM),
        .SYNC_STAGES(SYNC_STAGES)
    ) bfm (
        .wr_clk_i(wr_clk),
        .rd_clk_i(rd_clk)
    );

    queue_carriage #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .ASYNC(ASYNC),
        .PUSH_SIMPLE(PUSH_SIMPLE),
        .PUSH_BURST_SIZE(PUSH_BURST_SIZE),
        .POP_BURSTMARK(POP_BURSTMARK),
        .CONFLICT_PROOF(CONFLICT_PROOF),
        .REGISTERED_IN(REGISTERED_IN),
        .REGISTERED_IN_BRAM(REGISTERED_IN_BRAM),
        .REGISTERED_OUT_BRAM(REGISTERED_OUT_BRAM),
        .SYNC_STAGES(SYNC_STAGES)
    ) dut (
        .wr_clk_i(wr_clk),
        .wr_rst_i(bfm.wr_rst_i),
        .wr_data_i(bfm.wr_data_i),
        .wr_valid_i(bfm.wr_valid_i),
        .wr_ready_o(bfm.wr_ready_o),
        .wr_burstready_o(bfm.wr_burstready_o),

        .rd_clk_i(rd_clk),
        .rd_rst_i(bfm.rd_rst_i),
        .rd_data_o(bfm.rd_data_o),
        .rd_valid_o(bfm.rd_valid_o),
        .rd_burstvalid_o(bfm.rd_burstvalid_o),
        .rd_ready_i(bfm.rd_ready_i)
    );

    initial begin
        static TriggerableQueueBroadcaster #(T) dut_generator_out_broadcast = new();
        static QueueCarriageGenerator #(T) dut_generator = new(dut_generator_out_broadcast);

        static TriggerableQueueBroadcaster #(T) model_generator_out_broadcast = new();
        static QueueCarriageGenerator #(T) model_generator = new(model_generator_out_broadcast);

        static TriggerableQueue #(T) driver_in_queue = new();
        static QueueCarriageDriver #(T, I) driver = new(driver_in_queue, bfm);

        static TriggerableQueue #(T) golden_in_queue = new();
        static TriggerableQueueBroadcaster #(T) golden_out_broadcast = new();
        static QueueCarriageModel #(T) golden = new(golden_in_queue, golden_out_broadcast);

        static TriggerableQueueBroadcaster #(T) monitor_out_broadcast = new();
        static QueueCarriageMonitor #(T, I) monitor = new(monitor_out_broadcast, bfm);

        static TriggerableQueue #(T) scoreboard_in_queue_dut = new();
        static TriggerableQueue #(T) scoreboard_in_queue_golden = new();
        static QueueCarriageScoreboard #(T) scoreboard = new(
            scoreboard_in_queue_dut,
            scoreboard_in_queue_golden
        );

        dut_generator_out_broadcast.add_queue(driver_in_queue);
        model_generator_out_broadcast.add_queue(golden_in_queue);
        monitor_out_broadcast.add_queue(scoreboard_in_queue_dut);
        golden_out_broadcast.add_queue(scoreboard_in_queue_golden);

        $dumpfile("waves.vcd");
        $dumpvars(0, queue_carriage_tb);

        bfm.wr_rst_i = 0;
        bfm.rd_rst_i = 0;
        bfm.wr_data_i = '0;
        bfm.wr_valid_i = 0;
        bfm.rd_ready_i = 0;
        bfm.start_sequence = 0;
        bfm.end_sequence = 0;
        bfm.end_last_sequence = 0;
        bfm.idle = 1;
        @(posedge wr_clk);

        fork
            dut_generator.run();
            model_generator.run();
            driver.run();
            golden.run();
            monitor.run();
            scoreboard.run();
        join_none

        #200000;
        $fatal(1, "QueueCarriage testbench timeout");
    end
endmodule
