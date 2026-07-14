////////////////////////////////////////////////////////////////
// rtl utilities include and imports
`include "rtl_utilities_pkg.sv"
import constant_functions_pkg::*;

////////////////////////////////////////////////////////////////
// interface include
`include "aligner_inf.svh"

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
`include "io_circuits/multistage_fanout/multistage_fanout.sv"
`include "processing_elements/max/max.sv"
`include "processing_elements/equal/equal.sv"
`include "processing_elements/priority_encoder/priority_encoder.sv"
`include "processing_elements/reduction_tree/reduction_tree.sv"
`include "processing_elements/multistage_mux/multistage_mux.sv"
`include "processing_elements/aligner/aligner.sv"

////////////////////////////////////////////////////////////////
// timescale
`timescale 1ns / 1ns

module aligner_tb #(
    parameter DATA_WIDTH = 8,
    parameter SIZE = 4,
    parameter REGISTERED_IN = 1,
    parameter START_SYMBOL_FANOUT_FACTOR = 4,
    parameter REGISTERED_IN_START_SYMBOL = 1,
    parameter REGISTERED_IN_EQUAL = 1,
    parameter REGISTERED_IN_PRIORITY_ENCODER = 1,
    parameter REGISTERED_IN_REDUCTION_TREE = 1,
    parameter REGISTERED_IN_MULTISTAGE_MUX = 1,
    parameter LUTX_EQUAL = 4,
    parameter LUTX_PRIORITY_ENCODER = 4,
    parameter LUTX_REDUCTION_TREE = 4,
    parameter LUTX_MULTISTAGE_MUX = 4,
    parameter GRADE_EQUAL = 1,
    parameter GRADE_PRIORITY_ENCODER = 1,
    parameter GRADE_REDUCTION_TREE = 1,
    parameter GRADE_MULTISTAGE_MUX = 1
) ();

    localparam real CLK_PERIOD = 10;

    localparam type T = AlignerIO #(
        .DATA_WIDTH(DATA_WIDTH),
        .SIZE(SIZE),
        .REGISTERED_IN(REGISTERED_IN),
        .START_SYMBOL_FANOUT_FACTOR(START_SYMBOL_FANOUT_FACTOR),
        .REGISTERED_IN_START_SYMBOL(REGISTERED_IN_START_SYMBOL),
        .REGISTERED_IN_EQUAL(REGISTERED_IN_EQUAL),
        .REGISTERED_IN_PRIORITY_ENCODER(REGISTERED_IN_PRIORITY_ENCODER),
        .REGISTERED_IN_REDUCTION_TREE(REGISTERED_IN_REDUCTION_TREE),
        .REGISTERED_IN_MULTISTAGE_MUX(REGISTERED_IN_MULTISTAGE_MUX),
        .LUTX_EQUAL(LUTX_EQUAL),
        .LUTX_PRIORITY_ENCODER(LUTX_PRIORITY_ENCODER),
        .LUTX_REDUCTION_TREE(LUTX_REDUCTION_TREE),
        .LUTX_MULTISTAGE_MUX(LUTX_MULTISTAGE_MUX),
        .GRADE_EQUAL(GRADE_EQUAL),
        .GRADE_PRIORITY_ENCODER(GRADE_PRIORITY_ENCODER),
        .GRADE_REDUCTION_TREE(GRADE_REDUCTION_TREE),
        .GRADE_MULTISTAGE_MUX(GRADE_MULTISTAGE_MUX)
    );

    localparam type I = virtual aligner_inf #(
        .DATA_WIDTH(DATA_WIDTH),
        .SIZE(SIZE),
        .REGISTERED_IN(REGISTERED_IN),
        .START_SYMBOL_FANOUT_FACTOR(START_SYMBOL_FANOUT_FACTOR),
        .REGISTERED_IN_START_SYMBOL(REGISTERED_IN_START_SYMBOL),
        .REGISTERED_IN_EQUAL(REGISTERED_IN_EQUAL),
        .REGISTERED_IN_PRIORITY_ENCODER(REGISTERED_IN_PRIORITY_ENCODER),
        .REGISTERED_IN_REDUCTION_TREE(REGISTERED_IN_REDUCTION_TREE),
        .REGISTERED_IN_MULTISTAGE_MUX(REGISTERED_IN_MULTISTAGE_MUX),
        .LUTX_EQUAL(LUTX_EQUAL),
        .LUTX_PRIORITY_ENCODER(LUTX_PRIORITY_ENCODER),
        .LUTX_REDUCTION_TREE(LUTX_REDUCTION_TREE),
        .LUTX_MULTISTAGE_MUX(LUTX_MULTISTAGE_MUX),
        .GRADE_EQUAL(GRADE_EQUAL),
        .GRADE_PRIORITY_ENCODER(GRADE_PRIORITY_ENCODER),
        .GRADE_REDUCTION_TREE(GRADE_REDUCTION_TREE),
        .GRADE_MULTISTAGE_MUX(GRADE_MULTISTAGE_MUX)
    );

    logic clk = 0;
    always begin #(CLK_PERIOD / 2); clk = ~clk; end

    aligner_inf #(
        .DATA_WIDTH(DATA_WIDTH),
        .SIZE(SIZE),
        .REGISTERED_IN(REGISTERED_IN),
        .START_SYMBOL_FANOUT_FACTOR(START_SYMBOL_FANOUT_FACTOR),
        .REGISTERED_IN_START_SYMBOL(REGISTERED_IN_START_SYMBOL),
        .REGISTERED_IN_EQUAL(REGISTERED_IN_EQUAL),
        .REGISTERED_IN_PRIORITY_ENCODER(REGISTERED_IN_PRIORITY_ENCODER),
        .REGISTERED_IN_REDUCTION_TREE(REGISTERED_IN_REDUCTION_TREE),
        .REGISTERED_IN_MULTISTAGE_MUX(REGISTERED_IN_MULTISTAGE_MUX),
        .LUTX_EQUAL(LUTX_EQUAL),
        .LUTX_PRIORITY_ENCODER(LUTX_PRIORITY_ENCODER),
        .LUTX_REDUCTION_TREE(LUTX_REDUCTION_TREE),
        .LUTX_MULTISTAGE_MUX(LUTX_MULTISTAGE_MUX),
        .GRADE_EQUAL(GRADE_EQUAL),
        .GRADE_PRIORITY_ENCODER(GRADE_PRIORITY_ENCODER),
        .GRADE_REDUCTION_TREE(GRADE_REDUCTION_TREE),
        .GRADE_MULTISTAGE_MUX(GRADE_MULTISTAGE_MUX)
    ) bfm (.clk_i(clk));

    aligner #(
        .DATA_WIDTH(DATA_WIDTH),
        .SIZE(SIZE),
        .REGISTERED_IN(REGISTERED_IN),
        .START_SYMBOL_FANOUT_FACTOR(START_SYMBOL_FANOUT_FACTOR),
        .REGISTERED_IN_START_SYMBOL(REGISTERED_IN_START_SYMBOL),
        .REGISTERED_IN_EQUAL(REGISTERED_IN_EQUAL),
        .REGISTERED_IN_PRIORITY_ENCODER(REGISTERED_IN_PRIORITY_ENCODER),
        .REGISTERED_IN_REDUCTION_TREE(REGISTERED_IN_REDUCTION_TREE),
        .REGISTERED_IN_MULTISTAGE_MUX(REGISTERED_IN_MULTISTAGE_MUX),
        .LUTX_EQUAL(LUTX_EQUAL),
        .LUTX_PRIORITY_ENCODER(LUTX_PRIORITY_ENCODER),
        .LUTX_REDUCTION_TREE(LUTX_REDUCTION_TREE),
        .LUTX_MULTISTAGE_MUX(LUTX_MULTISTAGE_MUX),
        .GRADE_EQUAL(GRADE_EQUAL),
        .GRADE_PRIORITY_ENCODER(GRADE_PRIORITY_ENCODER),
        .GRADE_REDUCTION_TREE(GRADE_REDUCTION_TREE),
        .GRADE_MULTISTAGE_MUX(GRADE_MULTISTAGE_MUX)
    ) dut (
        .clk_i(clk),
        .data_i(bfm.data_i),
        .start_symbol_i(bfm.start_symbol_i),
        .aligned_o(bfm.aligned_o),
        .matched_o(bfm.matched_o)
    );

    initial begin
        static TriggerableQueueBroadcaster #(T) dut_generator_out_broadcast = new();
        static AlignerGenerator #(T) dut_generator = new(dut_generator_out_broadcast);

        static TriggerableQueueBroadcaster #(T) model_generator_out_broadcast = new();
        static AlignerGenerator #(T) model_generator = new(model_generator_out_broadcast);

        static TriggerableQueue #(T) driver_in_queue = new();
        static AlignerDriver #(T, I) driver = new(driver_in_queue, bfm);

        static TriggerableQueue #(T) golden_in_queue = new();
        static TriggerableQueueBroadcaster #(T) golden_out_broadcast = new();
        static AlignerModel #(T) golden = new(golden_in_queue, golden_out_broadcast);

        static TriggerableQueueBroadcaster #(T) monitor_out_broadcast = new();
        static AlignerMonitor #(T, I) monitor = new(monitor_out_broadcast, bfm);

        static TriggerableQueue #(T) scoreboard_in_queue_dut = new();
        static TriggerableQueue #(T) scoreboard_in_queue_golden = new();
        static AlignerScoreboard #(T) scoreboard = new(scoreboard_in_queue_dut, scoreboard_in_queue_golden);

        dut_generator_out_broadcast.add_queue(driver_in_queue);
        model_generator_out_broadcast.add_queue(golden_in_queue);
        monitor_out_broadcast.add_queue(scoreboard_in_queue_dut);
        golden_out_broadcast.add_queue(scoreboard_in_queue_golden);

        $dumpfile("waves.vcd");
        $dumpvars(0, aligner_tb);

        bfm.data_i = '0;
        bfm.start_symbol_i = '0;
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
        $error("Aligner testbench timed out");
        $finish;
    end
endmodule
