`include "rtl_utilities_pkg.sv"
import constant_functions_pkg::*;
`include "alternate_base_fp_adder_inf.svh"
`include "utilities_pkg.svh"
`include "io_pkg.svh"
`include "drivers_pkg.svh"
`include "generators_pkg.svh"
`include "golden_models_pkg.svh"
`include "monitors_pkg.svh"
`include "scoreboards_pkg.svh"
import utilities_pkg::*;
import io_pkg::*;
import drivers_pkg::*;
import generators_pkg::*;
import golden_models_pkg::*;
import monitors_pkg::*;
import scoreboards_pkg::*;

`include "io_circuits/pipe/pipe.sv"
`include "processing_elements/max/max.sv"
`include "processing_elements/multistage_mux/multistage_mux.sv"
`include "processing_elements/reduction_tree/reduction_tree.sv"
`include "processing_elements/priority_encoder/priority_encoder.sv"
`include "processing_elements/alternate_base_fp/alternate_base_fp_adder.sv"

`timescale 1ns/1ns
module alternate_base_fp_adder_tb #(
    parameter BASE = 16,
    parameter EXPONENT_WIDTH = 3,
    parameter MANTISSA_WIDTH = 12,
    parameter LUTX = 6,
    parameter GRADE = 1,
    parameter REGISTERED_SWAP_IN = 1,
    parameter REGISTERED_SWAP_MUX = 1,
    parameter REGISTERED_ALIGN_STICKY_IN = 1,
    parameter REGISTERED_ALIGN_EXPONENT_MUX = 1,
    parameter REGISTERED_ALIGN_MUX = 1,
    parameter REGISTERED_ADD_CONVERT = 1,
    parameter REGISTERED_ADD_CONVERT_CONVERT = 1,
    parameter REGISTERED_PRIORITY_ENCODE = 1,
    parameter REGISTERED_PRIORITY_ENCODE_ENCODER = 1,
    parameter REGISTERED_NORMALIZE_ROUND_POST_NORMALIZE = 1,
    parameter REGISTERED_NORMALIZE_ROUND_POST_NORMALIZE_ROUND = 1,
    parameter RANDOM_TRANSACTIONS = 256
) ();
    localparam real CLK_PERIOD = 10;
    localparam type T = AlternateBaseFpAdderIO #(
        .BASE(BASE),
        .EXPONENT_WIDTH(EXPONENT_WIDTH),
        .MANTISSA_WIDTH(MANTISSA_WIDTH),
        .LUTX(LUTX),
        .GRADE(GRADE),
        .REGISTERED_SWAP_IN(REGISTERED_SWAP_IN),
        .REGISTERED_SWAP_MUX(REGISTERED_SWAP_MUX),
        .REGISTERED_ALIGN_STICKY_IN(REGISTERED_ALIGN_STICKY_IN),
        .REGISTERED_ALIGN_EXPONENT_MUX(REGISTERED_ALIGN_EXPONENT_MUX),
        .REGISTERED_ALIGN_MUX(REGISTERED_ALIGN_MUX),
        .REGISTERED_ADD_CONVERT(REGISTERED_ADD_CONVERT),
        .REGISTERED_ADD_CONVERT_CONVERT(REGISTERED_ADD_CONVERT_CONVERT),
        .REGISTERED_PRIORITY_ENCODE(REGISTERED_PRIORITY_ENCODE),
        .REGISTERED_PRIORITY_ENCODE_ENCODER(REGISTERED_PRIORITY_ENCODE_ENCODER),
        .REGISTERED_NORMALIZE_ROUND_POST_NORMALIZE(REGISTERED_NORMALIZE_ROUND_POST_NORMALIZE),
        .REGISTERED_NORMALIZE_ROUND_POST_NORMALIZE_ROUND(REGISTERED_NORMALIZE_ROUND_POST_NORMALIZE_ROUND),
        .RANDOM_TRANSACTIONS(RANDOM_TRANSACTIONS)
    );
    localparam type I = virtual alternate_base_fp_adder_inf #(
        .BASE(BASE),
        .EXPONENT_WIDTH(EXPONENT_WIDTH),
        .MANTISSA_WIDTH(MANTISSA_WIDTH),
        .LUTX(LUTX),
        .GRADE(GRADE),
        .REGISTERED_SWAP_IN(REGISTERED_SWAP_IN),
        .REGISTERED_SWAP_MUX(REGISTERED_SWAP_MUX),
        .REGISTERED_ALIGN_STICKY_IN(REGISTERED_ALIGN_STICKY_IN),
        .REGISTERED_ALIGN_EXPONENT_MUX(REGISTERED_ALIGN_EXPONENT_MUX),
        .REGISTERED_ALIGN_MUX(REGISTERED_ALIGN_MUX),
        .REGISTERED_ADD_CONVERT(REGISTERED_ADD_CONVERT),
        .REGISTERED_ADD_CONVERT_CONVERT(REGISTERED_ADD_CONVERT_CONVERT),
        .REGISTERED_PRIORITY_ENCODE(REGISTERED_PRIORITY_ENCODE),
        .REGISTERED_PRIORITY_ENCODE_ENCODER(REGISTERED_PRIORITY_ENCODE_ENCODER),
        .REGISTERED_NORMALIZE_ROUND_POST_NORMALIZE(REGISTERED_NORMALIZE_ROUND_POST_NORMALIZE),
        .REGISTERED_NORMALIZE_ROUND_POST_NORMALIZE_ROUND(REGISTERED_NORMALIZE_ROUND_POST_NORMALIZE_ROUND)
    );
    logic clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;
    alternate_base_fp_adder_inf #(
        .BASE(BASE),
        .EXPONENT_WIDTH(EXPONENT_WIDTH),
        .MANTISSA_WIDTH(MANTISSA_WIDTH),
        .LUTX(LUTX),
        .GRADE(GRADE),
        .REGISTERED_SWAP_IN(REGISTERED_SWAP_IN),
        .REGISTERED_SWAP_MUX(REGISTERED_SWAP_MUX),
        .REGISTERED_ALIGN_STICKY_IN(REGISTERED_ALIGN_STICKY_IN),
        .REGISTERED_ALIGN_EXPONENT_MUX(REGISTERED_ALIGN_EXPONENT_MUX),
        .REGISTERED_ALIGN_MUX(REGISTERED_ALIGN_MUX),
        .REGISTERED_ADD_CONVERT(REGISTERED_ADD_CONVERT),
        .REGISTERED_ADD_CONVERT_CONVERT(REGISTERED_ADD_CONVERT_CONVERT),
        .REGISTERED_PRIORITY_ENCODE(REGISTERED_PRIORITY_ENCODE),
        .REGISTERED_PRIORITY_ENCODE_ENCODER(REGISTERED_PRIORITY_ENCODE_ENCODER),
        .REGISTERED_NORMALIZE_ROUND_POST_NORMALIZE(REGISTERED_NORMALIZE_ROUND_POST_NORMALIZE),
        .REGISTERED_NORMALIZE_ROUND_POST_NORMALIZE_ROUND(REGISTERED_NORMALIZE_ROUND_POST_NORMALIZE_ROUND)
    ) bfm(.clk_i(clk));
    alternate_base_fp_adder #(
        .BASE(BASE),
        .EXPONENT_WIDTH(EXPONENT_WIDTH),
        .MANTISSA_WIDTH(MANTISSA_WIDTH),
        .LUTX(LUTX),
        .GRADE(GRADE),
        .REGISTERED_SWAP_IN(REGISTERED_SWAP_IN),
        .REGISTERED_SWAP_MUX(REGISTERED_SWAP_MUX),
        .REGISTERED_ALIGN_STICKY_IN(REGISTERED_ALIGN_STICKY_IN),
        .REGISTERED_ALIGN_EXPONENT_MUX(REGISTERED_ALIGN_EXPONENT_MUX),
        .REGISTERED_ALIGN_MUX(REGISTERED_ALIGN_MUX),
        .REGISTERED_ADD_CONVERT(REGISTERED_ADD_CONVERT),
        .REGISTERED_ADD_CONVERT_CONVERT(REGISTERED_ADD_CONVERT_CONVERT),
        .REGISTERED_PRIORITY_ENCODE(REGISTERED_PRIORITY_ENCODE),
        .REGISTERED_PRIORITY_ENCODE_ENCODER(REGISTERED_PRIORITY_ENCODE_ENCODER),
        .REGISTERED_NORMALIZE_ROUND_POST_NORMALIZE(REGISTERED_NORMALIZE_ROUND_POST_NORMALIZE),
        .REGISTERED_NORMALIZE_ROUND_POST_NORMALIZE_ROUND(REGISTERED_NORMALIZE_ROUND_POST_NORMALIZE_ROUND)
    ) dut(.clk_i(clk), .a_i(bfm.a_i), .b_i(bfm.b_i), .sum_o(bfm.sum_o));

    initial begin
        static TriggerableQueueBroadcaster #(T) dut_generator_out_broadcast = new();
        static AlternateBaseFpAdderGenerator #(T) dut_generator = new(dut_generator_out_broadcast);
        static TriggerableQueueBroadcaster #(T) model_generator_out_broadcast = new();
        static AlternateBaseFpAdderGenerator #(T) model_generator = new(model_generator_out_broadcast);
        static TriggerableQueue #(T) driver_in_queue = new();
        static AlternateBaseFpAdderDriver #(T,I) driver = new(driver_in_queue, bfm);
        static TriggerableQueue #(T) golden_in_queue = new();
        static TriggerableQueueBroadcaster #(T) golden_out_broadcast = new();
        static AlternateBaseFpAdderModel #(T) golden = new(golden_in_queue, golden_out_broadcast);
        static TriggerableQueueBroadcaster #(T) monitor_out_broadcast = new();
        static AlternateBaseFpAdderMonitor #(T,I) monitor = new(monitor_out_broadcast, bfm);
        static TriggerableQueue #(T) scoreboard_in_queue_dut = new();
        static TriggerableQueue #(T) scoreboard_in_queue_golden = new();
        static AlternateBaseFpAdderScoreboard #(T) scoreboard = new(scoreboard_in_queue_dut, scoreboard_in_queue_golden);

        if(BASE < 2 || ((BASE & (BASE-1)) != 0)) $fatal(1, "BASE must be a power of two >= 2");
        if(EXPONENT_WIDTH < 1 || EXPONENT_WIDTH > 10) $fatal(1, "Exact golden model supports EXPONENT_WIDTH=1..10");
        if(MANTISSA_WIDTH < T::BASE_WIDTH) $fatal(1, "MANTISSA_WIDTH must be at least BASE_WIDTH");
        if(LUTX < 3 || (GRADE != 1 && GRADE != 2)) $fatal(1, "Use LUTX>=3 and GRADE=1 or 2");
        if(RANDOM_TRANSACTIONS < 0) $fatal(1, "RANDOM_TRANSACTIONS must be nonnegative");
        dut_generator_out_broadcast.add_queue(driver_in_queue);
        model_generator_out_broadcast.add_queue(golden_in_queue);
        monitor_out_broadcast.add_queue(scoreboard_in_queue_dut);
        golden_out_broadcast.add_queue(scoreboard_in_queue_golden);
        $dumpfile("waves.vcd");
        $dumpvars(0, alternate_base_fp_adder_tb);
        $display("BASE=%0d EXPONENT_WIDTH=%0d MANTISSA_WIDTH=%0d LUTX=%0d GRADE=%0d LATENCY=%0d",
                 BASE, EXPONENT_WIDTH, MANTISSA_WIDTH, LUTX, GRADE, T::LATENCY);
        bfm.a_i = '0;
        bfm.b_i = '0;
        bfm.idle = 1;
        // Resetless pipelines must fill before valid sequence markers are issued.
        repeat(T::LATENCY + 2) @(posedge clk);
        fork
            dut_generator.run();
            model_generator.run();
            driver.run();
            golden.run();
            monitor.run();
            scoreboard.run();
        join_none
        #(CLK_PERIOD * (2 * RANDOM_TRANSACTIONS + 4 * T::LATENCY + 4096));
        $fatal(1, "Testbench timed out before scoreboard completion");
    end
endmodule
