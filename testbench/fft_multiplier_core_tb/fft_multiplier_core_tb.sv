`timescale 1ns/1ns
`include "rtl_utilities_pkg.sv"
import constant_functions_pkg::*;
`include "fft_multiplier_core_inf.svh"
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
`include "processing_elements/reduction_tree/reduction_tree.sv"
`include "processing_elements/alternate_base_fp_multiplier/alternate_base_fp_multiplier.sv"
`include "processing_elements/fft_multiplier_core/fft_multiplier_core.sv"

module fft_multiplier_core_tb #(
    parameter BASE = 16,
    parameter EXPONENT_WIDTH = 3,
    parameter MANTISSA_WIDTH = 12,
    parameter LUTX = 6,
    parameter GRADE = 1,
    parameter REGSITERED_MULTIPLIER = 1,
    parameter REGISTERED_NORMALIZE = 1,
    parameter RANDOM_TRANSACTIONS = 256
) ();
    localparam real CLK_PERIOD = 10;
    localparam type T = FftMultiplierCoreIO #(
        .BASE(BASE),
        .EXPONENT_WIDTH(EXPONENT_WIDTH),
        .MANTISSA_WIDTH(MANTISSA_WIDTH),
        .LUTX(LUTX),
        .GRADE(GRADE),
        .REGSITERED_MULTIPLIER(REGSITERED_MULTIPLIER),
        .REGISTERED_NORMALIZE(REGISTERED_NORMALIZE),
        .RANDOM_TRANSACTIONS(RANDOM_TRANSACTIONS)
    );
    localparam type I = virtual fft_multiplier_core_inf #(
        .BASE(BASE),
        .EXPONENT_WIDTH(EXPONENT_WIDTH),
        .MANTISSA_WIDTH(MANTISSA_WIDTH),
        .LUTX(LUTX),
        .GRADE(GRADE),
        .REGSITERED_MULTIPLIER(REGSITERED_MULTIPLIER),
        .REGISTERED_NORMALIZE(REGISTERED_NORMALIZE)
    );
    logic clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;
    fft_multiplier_core_inf #(
        .BASE(BASE),
        .EXPONENT_WIDTH(EXPONENT_WIDTH),
        .MANTISSA_WIDTH(MANTISSA_WIDTH),
        .LUTX(LUTX),
        .GRADE(GRADE),
        .REGSITERED_MULTIPLIER(REGSITERED_MULTIPLIER),
        .REGISTERED_NORMALIZE(REGISTERED_NORMALIZE)
    ) bfm(.clk_i(clk));
    fft_multiplier_core #(
        .BASE(BASE),
        .EXPONENT_WIDTH(EXPONENT_WIDTH),
        .MANTISSA_WIDTH(MANTISSA_WIDTH),
        .LUTX(LUTX),
        .GRADE(GRADE),
        .REGSITERED_MULTIPLIER(REGSITERED_MULTIPLIER),
        .REGISTERED_NORMALIZE(REGISTERED_NORMALIZE)
    ) dut(
        .clk_i(clk), .rst_i(bfm.rst_i), .w_b_valid_i(bfm.w_b_valid_i),
        .wr_i(bfm.wr_i), .wi_i(bfm.wi_i), .br_i(bfm.br_i), .bi_i(bfm.bi_i),
        .ar_i(bfm.ar_i), .ai_i(bfm.ai_i), .wrbr_o(bfm.wrbr_o), .wibi_o(bfm.wibi_o),
        .wrbi_o(bfm.wrbi_o), .wibr_o(bfm.wibr_o), .ar_o(bfm.ar_o), .ai_o(bfm.ai_o),
        .valid_o(bfm.valid_o)
    );

    initial begin
        static TriggerableQueueBroadcaster #(T) dut_generator_out_broadcast = new();
        static FftMultiplierCoreGenerator #(T) dut_generator = new(dut_generator_out_broadcast);
        static TriggerableQueueBroadcaster #(T) model_generator_out_broadcast = new();
        static FftMultiplierCoreGenerator #(T) model_generator = new(model_generator_out_broadcast);
        static TriggerableQueue #(T) driver_in_queue = new();
        static FftMultiplierCoreDriver #(T,I) driver = new(driver_in_queue, bfm);
        static TriggerableQueue #(T) golden_in_queue = new();
        static TriggerableQueueBroadcaster #(T) golden_out_broadcast = new();
        static FftMultiplierCoreModel #(T) golden = new(golden_in_queue, golden_out_broadcast);
        static TriggerableQueueBroadcaster #(T) monitor_out_broadcast = new();
        static FftMultiplierCoreMonitor #(T,I) monitor = new(monitor_out_broadcast, bfm);
        static TriggerableQueue #(T) scoreboard_in_queue_dut = new();
        static TriggerableQueue #(T) scoreboard_in_queue_golden = new();
        static FftMultiplierCoreScoreboard #(T) scoreboard = new(scoreboard_in_queue_dut, scoreboard_in_queue_golden);

        if(BASE < 2 || ((BASE & (BASE-1)) != 0)) $fatal(1, "BASE must be a power of two >= 2");
        if(EXPONENT_WIDTH < 1) $fatal(1, "EXPONENT_WIDTH must be positive");
        if(MANTISSA_WIDTH < T::BASE_WIDTH) $fatal(1, "MANTISSA_WIDTH must be at least BASE_WIDTH");
        if(LUTX < 3 || (GRADE != 1 && GRADE != 2)) $fatal(1, "Use LUTX>=3 and GRADE=1 or 2");
        if((REGSITERED_MULTIPLIER != 0 && REGSITERED_MULTIPLIER != 1) ||
           (REGISTERED_NORMALIZE != 0 && REGISTERED_NORMALIZE != 1))
            $fatal(1, "REGISTERED_* parameters must be 0 or 1");
        if(RANDOM_TRANSACTIONS < 0) $fatal(1, "RANDOM_TRANSACTIONS must be nonnegative");
        dut_generator_out_broadcast.add_queue(driver_in_queue);
        model_generator_out_broadcast.add_queue(golden_in_queue);
        monitor_out_broadcast.add_queue(scoreboard_in_queue_dut);
        golden_out_broadcast.add_queue(scoreboard_in_queue_golden);
        $dumpfile("waves.vcd");
        $dumpvars(0, fft_multiplier_core_tb);
        $display("BASE=%0d EXPONENT_WIDTH=%0d MANTISSA_WIDTH=%0d LUTX=%0d GRADE=%0d LATENCY=%0d",
                 BASE, EXPONENT_WIDTH, MANTISSA_WIDTH, LUTX, GRADE, T::LATENCY);
        bfm.rst_i = 1;
        bfm.w_b_valid_i = 0;
        bfm.idle = 1;
        // Initialize only control. Data may remain unknown until its first qualified write.
        repeat(2) @(posedge clk);
        fork
            dut_generator.run();
            model_generator.run();
            driver.run();
            golden.run();
            monitor.run();
            scoreboard.run();
        join_none
        #(CLK_PERIOD * (20 * RANDOM_TRANSACTIONS + 24 * T::LATENCY * T::LATENCY + 32768));
        $fatal(1, "Testbench timed out before scoreboard completion");
    end
endmodule
