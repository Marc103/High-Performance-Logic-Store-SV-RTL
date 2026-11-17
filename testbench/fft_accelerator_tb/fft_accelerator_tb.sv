`timescale 1ns/1ns
`include "rtl_utilities_pkg.sv"
import constant_functions_pkg::*;
`include "fft_accelerator_inf.svh"
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
`include "processing_elements/max/max.sv"
`include "processing_elements/multistage_mux/multistage_mux.sv"
`include "processing_elements/priority_encoder/priority_encoder.sv"
`include "processing_elements/alternate_base_fp_adder/alternate_base_fp_adder.sv"
`include "processing_elements/alternate_base_fp_multiplier/alternate_base_fp_multiplier.sv"
`include "processing_elements/fft_multiplier_core/fft_multiplier_core.sv"
`include "processing_elements/fft_adder_core/fft_adder_core.sv"
`include "fsm/fsm_fft_reader/fsm_fft_reader.sv"
`include "fsm/fsm_fft_writer/fsm_fft_writer.sv"
`include "processing_elements/fft_accelerator/fft_accelerator.sv"
// File-driven FFT regression. Supply +SAMPLES_FILE, +TWIDDLES_FILE and
// +RESULT_FILE at run time; +FFT_POINTS/+FFT_COUNT select smaller transforms.
// The fixed fixture capacities are 32768 samples and 16384 twiddles.
module fft_accelerator_tb #(
    parameter BASE = 16,
    parameter EXPONENT_WIDTH = 6,
    parameter MANTISSA_WIDTH = 25,
    parameter SAMPLES_ADDR_WIDTH = 15,
    parameter TWIDDLES_ADDR_WIDTH = 14,
    parameter READ_LATENCY = 1,
    parameter WRITE_LATENCY = 1,
    parameter RESET_PIPELINE_DEPTH = 1,
    parameter LUTX = 6,
    parameter GRADE = 1,
    parameter REGSITERED_MULTIPLIER = 1,
    parameter REGISTERED_NORMALIZE = 1,
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
    parameter II_CYCLES = 4,
    parameter FFT_POINTS = 32768,
    parameter FFT_COUNT = 1,
    parameter string SAMPLES_FILE = "6_25_samples_0.txt",
    parameter string TWIDDLES_FILE = "6_25_twiddles_0.txt",
    parameter string RESULT_FILE = "6_25_result_0.txt"
) ();
    localparam real CLK_PERIOD=10;
    localparam type T=FftAcceleratorIO #(
        .BASE(BASE),
        .EXPONENT_WIDTH(EXPONENT_WIDTH),
        .MANTISSA_WIDTH(MANTISSA_WIDTH),
        .SAMPLES_ADDR_WIDTH(SAMPLES_ADDR_WIDTH),
        .TWIDDLES_ADDR_WIDTH(TWIDDLES_ADDR_WIDTH),
        .READ_LATENCY(READ_LATENCY),
        .WRITE_LATENCY(WRITE_LATENCY),
        .RESET_PIPELINE_DEPTH(RESET_PIPELINE_DEPTH),
        .LUTX(LUTX),
        .GRADE(GRADE),
        .REGSITERED_MULTIPLIER(REGSITERED_MULTIPLIER),
        .REGISTERED_NORMALIZE(REGISTERED_NORMALIZE),
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
        .II_CYCLES(II_CYCLES),
        .FFT_POINTS(FFT_POINTS),
        .FFT_COUNT(FFT_COUNT),
        .SAMPLES_FILE(SAMPLES_FILE),
        .TWIDDLES_FILE(TWIDDLES_FILE),
        .RESULT_FILE(RESULT_FILE)
    );
    localparam type I=virtual fft_accelerator_inf #(
        .BASE(BASE),
        .EXPONENT_WIDTH(EXPONENT_WIDTH),
        .MANTISSA_WIDTH(MANTISSA_WIDTH),
        .SAMPLES_ADDR_WIDTH(SAMPLES_ADDR_WIDTH),
        .TWIDDLES_ADDR_WIDTH(TWIDDLES_ADDR_WIDTH),
        .READ_LATENCY(READ_LATENCY),
        .WRITE_LATENCY(WRITE_LATENCY),
        .RESET_PIPELINE_DEPTH(RESET_PIPELINE_DEPTH),
        .LUTX(LUTX),
        .GRADE(GRADE),
        .REGSITERED_MULTIPLIER(REGSITERED_MULTIPLIER),
        .REGISTERED_NORMALIZE(REGISTERED_NORMALIZE),
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
        .II_CYCLES(II_CYCLES)
    );
    logic clk=0;
    always #(CLK_PERIOD/2) clk=~clk;
    fft_accelerator_inf #(
        .BASE(BASE),
        .EXPONENT_WIDTH(EXPONENT_WIDTH),
        .MANTISSA_WIDTH(MANTISSA_WIDTH),
        .SAMPLES_ADDR_WIDTH(SAMPLES_ADDR_WIDTH),
        .TWIDDLES_ADDR_WIDTH(TWIDDLES_ADDR_WIDTH),
        .READ_LATENCY(READ_LATENCY),
        .WRITE_LATENCY(WRITE_LATENCY),
        .RESET_PIPELINE_DEPTH(RESET_PIPELINE_DEPTH),
        .LUTX(LUTX),
        .GRADE(GRADE),
        .REGSITERED_MULTIPLIER(REGSITERED_MULTIPLIER),
        .REGISTERED_NORMALIZE(REGISTERED_NORMALIZE),
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
        .II_CYCLES(II_CYCLES)
    ) bfm(.clk_i(clk));
    fft_accelerator #(
        .BASE(BASE),
        .EXPONENT_WIDTH(EXPONENT_WIDTH),
        .MANTISSA_WIDTH(MANTISSA_WIDTH),
        .SAMPLES_ADDR_WIDTH(SAMPLES_ADDR_WIDTH),
        .TWIDDLES_ADDR_WIDTH(TWIDDLES_ADDR_WIDTH),
        .READ_LATENCY(READ_LATENCY),
        .WRITE_LATENCY(WRITE_LATENCY),
        .RESET_PIPELINE_DEPTH(RESET_PIPELINE_DEPTH),
        .LUTX(LUTX),
        .GRADE(GRADE),
        .REGSITERED_MULTIPLIER(REGSITERED_MULTIPLIER),
        .REGISTERED_NORMALIZE(REGISTERED_NORMALIZE),
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
        .II_CYCLES(II_CYCLES)
    ) dut(
        .clk_i(clk), .rst_i(bfm.rst_i), .go_i(bfm.go_i),
        .fft_point_size_i(bfm.fft_point_size_i), .fft_whole_iterations_i(bfm.fft_whole_iterations_i),
        .busy_o(bfm.busy_o), .fft_done_o(bfm.fft_done_o),
        .samples_rd_addr_o(bfm.samples_rd_addr_o), .samples_rd_en_o(bfm.samples_rd_en_o), .samples_rd_data_i(bfm.samples_rd_data_i),
        .samples_wr_addr_o(bfm.samples_wr_addr_o), .samples_wr_data_o(bfm.samples_wr_data_o), .samples_wr_en_o(bfm.samples_wr_en_o),
        .twiddles_rd_addr_o(bfm.twiddles_rd_addr_o), .twiddles_rd_en_o(bfm.twiddles_rd_en_o), .twiddles_rd_data_i(bfm.twiddles_rd_data_i)
    );
    // Fixed-capacity external memory model. Queued load/snapshot requests are
    // serviced only outside memory traffic; arrays never cross the virtual interface.
    logic [2*(1+EXPONENT_WIDTH+MANTISSA_WIDTH)-1:0] samples[32768], twiddles[16384];
    logic [READ_LATENCY-1:0][2*(1+EXPONENT_WIDTH+MANTISSA_WIDTH)-1:0] sample_read_pipe, twiddle_read_pipe;
    always @(posedge clk) begin
        if(bfm.samples_rd_en_o) sample_read_pipe[0] <= samples[bfm.samples_rd_addr_o];
        if(bfm.twiddles_rd_en_o) twiddle_read_pipe[0] <= twiddles[bfm.twiddles_rd_addr_o];
        for(int i=1;i<READ_LATENCY;i++) begin
            sample_read_pipe[i] <= sample_read_pipe[i-1];
            twiddle_read_pipe[i] <= twiddle_read_pipe[i-1];
        end
    end
    assign bfm.samples_rd_data_i=sample_read_pipe[READ_LATENCY-1];
    assign bfm.twiddles_rd_data_i=twiddle_read_pipe[READ_LATENCY-1];
    generate
        if(WRITE_LATENCY==1) begin : gen_write_direct
            always @(posedge clk) begin
                bfm.commit_en <= bfm.samples_wr_en_o;
                bfm.commit_address <= bfm.samples_wr_addr_o; bfm.commit_data <= bfm.samples_wr_data_o;
                if(bfm.samples_wr_en_o) samples[bfm.samples_wr_addr_o]=bfm.samples_wr_data_o;
            end
        end else begin : gen_write_pipeline
            logic [WRITE_LATENCY-2:0] enables='0;
            logic [WRITE_LATENCY-2:0][SAMPLES_ADDR_WIDTH-1:0] addresses;
            logic [WRITE_LATENCY-2:0][2*(1+EXPONENT_WIDTH+MANTISSA_WIDTH)-1:0] words;
            always @(posedge clk) begin
                enables[0] <= bfm.samples_wr_en_o; addresses[0] <= bfm.samples_wr_addr_o; words[0] <= bfm.samples_wr_data_o;
                for(int i=1;i<WRITE_LATENCY-1;i++) begin
                    enables[i] <= enables[i-1]; addresses[i] <= addresses[i-1]; words[i] <= words[i-1];
                end
                bfm.commit_en <= enables[WRITE_LATENCY-2];
                bfm.commit_address <= addresses[WRITE_LATENCY-2]; bfm.commit_data <= words[WRITE_LATENCY-2];
                if(enables[WRITE_LATENCY-2]) samples[addresses[WRITE_LATENCY-2]]=words[WRITE_LATENCY-2];
            end
        end
    endgenerate
    initial begin
        static TriggerableQueueBroadcaster #(T) dut_generator_out_broadcast = new();
        static FftAcceleratorGenerator #(T) dut_generator = new(dut_generator_out_broadcast);
        static TriggerableQueueBroadcaster #(T) model_generator_out_broadcast = new();
        static FftAcceleratorGenerator #(T) model_generator = new(model_generator_out_broadcast);
        static TriggerableQueue #(T) driver_in_queue = new();
        static TriggerableQueue #(T) monitor_metadata = new();
        static TriggerableQueue #(T) load_requests = new(), load_done = new();
        static TriggerableQueue #(T) snapshot_requests = new(), snapshot_done = new();
        static FftAcceleratorDriver #(T,I) driver = new(driver_in_queue, bfm, monitor_metadata, load_requests, load_done);
        static TriggerableQueue #(T) golden_in_queue = new();
        static TriggerableQueueBroadcaster #(T) golden_out_broadcast = new();
        static FftAcceleratorModel #(T) golden = new(golden_in_queue, golden_out_broadcast);
        static TriggerableQueueBroadcaster #(T) monitor_out_broadcast = new();
        static FftAcceleratorMonitor #(T,I) monitor = new(monitor_out_broadcast, bfm, monitor_metadata, snapshot_requests, snapshot_done);
        static TriggerableQueue #(T) scoreboard_in_queue_dut = new();
        static TriggerableQueue #(T) scoreboard_in_queue_golden = new();
        static FftAcceleratorScoreboard #(T) scoreboard = new(scoreboard_in_queue_dut, scoreboard_in_queue_golden);

        if(EXPONENT_WIDTH<1 || EXPONENT_WIDTH>10) $fatal(1,"Exact golden model supports EXPONENT_WIDTH=1..10");
        if(SAMPLES_ADDR_WIDTH<1 || SAMPLES_ADDR_WIDTH>15 || TWIDDLES_ADDR_WIDTH<1 || TWIDDLES_ADDR_WIDTH>14)
            $fatal(1,"This TB supports sample/twiddle address widths up to 15/14 (32K/16K)");
        if(READ_LATENCY<1 || WRITE_LATENCY<1 || RESET_PIPELINE_DEPTH<0) $fatal(1,"Invalid memory/reset latency");
        dut_generator_out_broadcast.add_queue(driver_in_queue);
        model_generator_out_broadcast.add_queue(golden_in_queue);
        monitor_out_broadcast.add_queue(scoreboard_in_queue_dut);
        golden_out_broadcast.add_queue(scoreboard_in_queue_golden);
        if($test$plusargs("DUMP_WAVES")) begin
            $dumpfile("waves.vcd"); $dumpvars(0,fft_accelerator_tb);
        end
        $display("FFT file TB: BASE=%0d EXPONENT_WIDTH=%0d MANTISSA_WIDTH=%0d II=%0d R=%0d W=%0d",
                 BASE,EXPONENT_WIDTH,MANTISSA_WIDTH,II_CYCLES,READ_LATENCY,WRITE_LATENCY);
        bfm.rst_i=1; bfm.go_i=0; bfm.loading=1;
        repeat(2) @(posedge clk);
        fork
            begin : load_memory_service
                T job;
                forever begin
                    load_requests.pop(job);
                    if(!bfm.loading || !bfm.rst_i) $fatal(1,"Memory load outside reset/loading phase");
                    foreach(job.initial_samples[i]) samples[i]=job.initial_samples[i];
                    foreach(job.twiddles[i]) twiddles[i]=job.twiddles[i];
                    job.loaded_samples=new[32768]; job.loaded_twiddles=new[16384];
                    foreach(job.loaded_samples[i]) job.loaded_samples[i]=samples[i];
                    foreach(job.loaded_twiddles[i]) job.loaded_twiddles[i]=twiddles[i];
                    load_done.push(job);
                end
            end
            begin : snapshot_memory_service
                T job;
                forever begin
                    snapshot_requests.pop(job);
                    job.final_samples=new[32768];
                    foreach(job.final_samples[i]) job.final_samples[i]=samples[i];
                    snapshot_done.push(job);
                end
            end
            dut_generator.run();
            model_generator.run();
            driver.run();
            golden.run();
            monitor.run();
            scoreboard.run();
        join_none
        // The driver derives a tighter run timeout from the selected runtime N/M.
        #(CLK_PERIOD * (32768.0 * 15.0 * (II_CYCLES+1) + 100000.0));
        $fatal(1, "Testbench timed out before scoreboard completion");
    end
endmodule
