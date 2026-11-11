/*
FFT FSM for reading A,B and W (twiddle) values
Intended to work with fft_* related modules but its interface
is quite generic.

SAMPLES_ADDR_WIDTH:
- Sample address width. The sample memory holds 2**SAMPLES_ADDR_WIDTH values.
- Must be >= 1. The existing int-valued BRAM DATA_DEPTH helper supports positive
  depths through SAMPLES_ADDR_WIDTH=30; larger depths need a wider depth helper.

TWIDDLES_ADDR_WIDTH:
- Twiddle address width; must be >= 1. The table can hold
  2**TWIDDLES_ADDR_WIDTH complex twiddle coefficients.
- Assuming the table stores the N/2 distinct coefficients W_N**k,
  k=0..N/2-1, do not request an N-point FFT larger than
  2**(TWIDDLES_ADDR_WIDTH + 1). Larger N would require unavailable twiddle entries.
- The table contents/address ordering must match the requested FFT configuration;
  sufficient address capacity alone does not provide the correct coefficients.

II_CYCLES:
- Must be a positive int >= 2.
- CYCLES_WIDTH is max(1, ceil(log2(II_CYCLES))) for a counter from 0 to II_CYCLES-1.

Runtime configuration:
- fft_point_size_i is N, a power of two >= 2, with
  N <= min(2**SAMPLES_ADDR_WIDTH, 2**(TWIDDLES_ADDR_WIDTH + 1)).
- fft_whole_iterations_i is the positive number of independent N-point FFTs in
  sample memory. Require N * fft_whole_iterations_i <= 2**SAMPLES_ADDR_WIDTH.
- Hold the configuration stable while running. These are caller requirements;
  this FSM does not validate the requested sizes.

Internal widths:
- group_size includes an extra bit to represent N=2**SAMPLES_ADDR_WIDTH.
- no_of_groups, pairs_per_group, a_b_gap_size, and their pair/group counters
  need at most N/2 during an active stage. whole_counter reaches at most the
  configured whole-FFT count, which is at most 2**(SAMPLES_ADDR_WIDTH-1).
- Sample and twiddle pointers are address-width values; overflowing address bits
  are discarded. The widened group_size is not an address.
- Stage parameters are doubled even when the final stage completes. Values for
  that nonexistent next stage are unused after state returns to IDLE_RESET and
  may wrap; active-stage values must fit as described above.

*/

import constant_functions_pkg::*;

module fsm_fft_reader #(
    parameter DATA_WIDTH,
    parameter SAMPLES_ADDR_WIDTH,
    parameter TWIDDLES_ADDR_WIDTH,
    parameter II_CYCLES,

    ////////////////////////////////////////////////////////////////
    // Globally Defined Locally Set Parameters
    localparam DATA_DEPTH   = bram_single_port_DATA_DEPTH(SAMPLES_ADDR_WIDTH),
    localparam CYCLES_WIDTH = fsm_fft_reader_CYCLES_WIDTH(II_CYCLES)

) (
    input                                clk_i,
    input                                rst_i,

    input  [SAMPLES_ADDR_WIDTH : 0]      fft_point_size_i,
    input  [SAMPLES_ADDR_WIDTH - 1 : 0]  fft_whole_iterations_i,

    input                                go_i,

    output [SAMPLES_ADDR_WIDTH - 1 : 0]  a_b_rd_addr_o,
    output                               a_b_rd_en_o,
    output                               a_valid_o,
    output                               b_valid_o,

    output [TWIDDLES_ADDR_WIDTH - 1 : 0] w_rd_addr_o,
    output                               w_rd_en_o,
    output                               w_valid_o

);

    // Unconditional input register stage, including reset.
    logic                                rst;
    logic  [SAMPLES_ADDR_WIDTH : 0]      fft_point_size;
    logic  [SAMPLES_ADDR_WIDTH - 1 : 0]  fft_whole_iterations; // how many N-point FFTs to process in the Sample space
    logic                                go;

    // Current values.
    logic                                state;
    logic  [SAMPLES_ADDR_WIDTH - 1 : 0]  gbi_a;                  // 'gbi' stands for group base index
    logic  [SAMPLES_ADDR_WIDTH - 1 : 0]  gbo_a;                  // 'gbo' stands for group base offset
    logic  [SAMPLES_ADDR_WIDTH - 1 : 0]  gbi_b;
    logic  [SAMPLES_ADDR_WIDTH - 1 : 0]  gbo_b;
    logic  [TWIDDLES_ADDR_WIDTH - 1 : 0] tbo_w;                  // 'tbo' stands for twiddle base offset
    logic  [SAMPLES_ADDR_WIDTH : 0]      group_size;             // up to N, including the full memory depth
    logic  [SAMPLES_ADDR_WIDTH - 1 : 0]  a_b_gap_size;           // gap between A, B base addresses, starts at 1
    logic  [SAMPLES_ADDR_WIDTH - 1 : 0]  no_of_groups;           // groups in a given stage in an N-point FFT, starts at N/2
    logic  [SAMPLES_ADDR_WIDTH - 1 : 0]  pairs_per_group;        // pairs per group in a given stage, starts at 1

    logic  [SAMPLES_ADDR_WIDTH - 1 : 0]  pair_counter;           // pair counter
    logic  [SAMPLES_ADDR_WIDTH - 0 : 0]  group_counter;          // group counter
    logic  [SAMPLES_ADDR_WIDTH - 1 : 0]  whole_counter;          // counts fft whole iterations
    logic  [CYCLES_WIDTH - 1 : 0]        cycles_counter;         // cycle counter to wait after both b/w then a reads are ushered 

    logic                                a_bw_toggle;            // b/w or a read being ushered?
    logic  [1:0]                         a_bw_done;              // both b/w and a done, need 2-bits to separate idle/transmission

    logic                                fft_done;           

    logic                                usher_a;
    logic  [SAMPLES_ADDR_WIDTH - 1 : 0]  usher_a_addr;

    logic                                usher_b;
    logic  [SAMPLES_ADDR_WIDTH - 1 : 0]  usher_b_addr;

    logic                                usher_w;
    logic  [TWIDDLES_ADDR_WIDTH - 1 : 0] usher_w_addr;

    // Corresponding next values
    logic                                state_next;
    logic  [SAMPLES_ADDR_WIDTH - 1 : 0]  gbi_a_next;
    logic  [SAMPLES_ADDR_WIDTH - 1 : 0]  gbo_a_next;
    logic  [SAMPLES_ADDR_WIDTH - 1 : 0]  gbi_b_next;
    logic  [SAMPLES_ADDR_WIDTH - 1 : 0]  gbo_b_next;
    logic  [TWIDDLES_ADDR_WIDTH - 1 : 0] tbo_w_next;
    logic  [SAMPLES_ADDR_WIDTH : 0]      group_size_next;
    logic  [SAMPLES_ADDR_WIDTH - 1 : 0]  a_b_gap_size_next;
    logic  [SAMPLES_ADDR_WIDTH - 1 : 0]  no_of_groups_next;
    logic  [SAMPLES_ADDR_WIDTH - 1 : 0]  pairs_per_group_next;

    logic  [SAMPLES_ADDR_WIDTH - 1 : 0]  pair_counter_next;
    logic  [SAMPLES_ADDR_WIDTH - 0 : 0]  group_counter_next;
    logic  [SAMPLES_ADDR_WIDTH - 1 : 0]  whole_counter_next;
    logic  [CYCLES_WIDTH - 1 : 0]        cycles_counter_next;

    logic                                a_bw_toggle_next;
    logic  [1:0]                         a_bw_done_next;

    logic                                fft_done_next;

    logic                                usher_a_next;
    logic  [SAMPLES_ADDR_WIDTH - 1 : 0]  usher_a_addr_next;

    logic                                usher_b_next;
    logic  [SAMPLES_ADDR_WIDTH - 1 : 0]  usher_b_addr_next;

    logic                                usher_w_next;
    logic  [TWIDDLES_ADDR_WIDTH - 1 : 0] usher_w_addr_next;

    always @(posedge clk_i) begin
        rst                  <= rst_i;
        fft_point_size       <= fft_point_size_i;
        fft_whole_iterations <= fft_whole_iterations_i;
        go                   <= go_i;

        state                <= state_next;
        gbi_a                <= gbi_a_next;
        gbo_a                <= gbo_a_next;
        gbi_b                <= gbi_b_next;
        gbo_b                <= gbo_b_next;
        tbo_w                <= tbo_w_next;
        group_size           <= group_size_next;
        a_b_gap_size          <= a_b_gap_size_next;
        no_of_groups         <= no_of_groups_next;
        pairs_per_group      <= pairs_per_group_next;

        pair_counter         <= pair_counter_next;
        group_counter        <= group_counter_next;
        whole_counter        <= whole_counter_next;
        cycles_counter       <= cycles_counter_next;

        a_bw_toggle          <= a_bw_toggle_next;
        a_bw_done            <= a_bw_done_next;

        fft_done             <= fft_done_next;

        usher_a              <= usher_a_next;
        usher_a_addr         <= usher_a_addr_next;

        usher_b              <= usher_b_next;
        usher_b_addr         <= usher_b_addr_next;

        usher_w              <= usher_w_next;
        usher_w_addr         <= usher_w_addr_next;
    end

    always_comb begin
        // regardless defaults
        usher_a_next      = 0;
        usher_a_addr_next = gbo_a;

        usher_b_next      = 0;
        usher_b_addr_next = gbo_b;

        usher_w_next      = 0;
        usher_w_addr_next = tbo_w;

        case (state)
            0: begin // IDLE_RESET
                // defaults
                gbi_a_next            = 0;
                gbo_a_next            = 0;
                gbi_b_next            = 1; // default of a_b_gap_size.
                gbo_b_next            = 1; 
                tbo_w_next            = 0;
   
                no_of_groups_next    = fft_point_size >> 1;
                pairs_per_group_next = 1;
                group_size_next      = 2;
                a_b_gap_size_next    = 1;

                pair_counter_next    = 0;
                group_counter_next   = 0;
                whole_counter_next   = 0;
                cycles_counter_next  = 0;

                a_bw_toggle_next     = 1; // we start with b and w
                a_bw_done_next       = 0;

                fft_done_next        = 0;

                state_next           = 0;
                if(go)  state_next   = 1;
            end

            1: begin // RUNNING
                // defaults, most maintain current state as default, other indicated with * comment
                gbi_a_next           = gbi_a;
                gbo_a_next           = gbo_a;
                gbi_b_next           = gbi_b;
                gbo_b_next           = gbo_b;
                tbo_w_next           = tbo_w;

                no_of_groups_next    = no_of_groups;
                pairs_per_group_next = pairs_per_group;
                group_size_next      = group_size;
                a_b_gap_size_next    = a_b_gap_size;

                pair_counter_next    = pair_counter;
                group_counter_next   = group_counter;
                whole_counter_next   = whole_counter;
                cycles_counter_next  = cycles_counter + 1; //*

                a_bw_toggle_next     = a_bw_toggle; 
                a_bw_done_next       = 0;                  //*

                fft_done_next        = 0;                  //*

                state_next           = state;

                if(a_bw_toggle) begin // toggle starts 1'b1 -> b/w read first
                    usher_b_next     = 1;
                    usher_w_next     = 1;
                    a_bw_toggle_next = 0;
                    a_bw_done_next   = 2'b01;
                end else begin       
                    if(a_bw_done == 2'b01) begin // 2-bit a_bw_done, to separate a usher from idle cycles
                        usher_a_next     = 1;
                        a_bw_done_next   = 2'b11;
                    end 
                    if(cycles_counter >= (II_CYCLES - 1)) begin
                        cycles_counter_next = 0; // reset cycle counter

                        a_bw_done_next     = 0; // reset done from 2'b11
                        a_bw_toggle_next   = 1; // reset toggle back to bw

                        gbo_a_next = gbo_a + 1; // increment A offset
                        gbo_b_next = gbo_b + 1; // increment B offset

                        pair_counter_next = pair_counter + 1;
                        if(pair_counter_next >= pairs_per_group) begin; // finished group
                            pair_counter_next = 0; // reset pair counter

                            gbi_a_next = gbi_a + group_size;   // increment A base pointer using group size
                            gbi_b_next = gbi_b + group_size;   // incrememt B base pointer using group size
                            gbo_a_next = gbi_a_next;           // set A offset to A base pointer
                            gbo_b_next = gbi_b_next;           // set B offset to B base pointer
                            tbo_w_next = tbo_w + no_of_groups; // the twiddle step size is equal to the number of groups
                            
                            group_counter_next = group_counter + 1;
                            if(group_counter_next >= no_of_groups) begin // finished all groups in N-point FFT
                                group_counter_next = 0; // reset group counter

                                tbo_w_next         = 0; // unlike the gbi/o_* variables, which tile over correctly
                                                        // we need to reset the twiddle base between successive N-point FFTs. 

                                whole_counter_next = whole_counter + 1;
                                if(whole_counter_next >= fft_whole_iterations) begin // finished all groups across all N-point FFT tiled over the Sample Space
                                    whole_counter_next = 0; // reset whole counter

                                    no_of_groups_next     = no_of_groups    >> 1;  // number of groups halves
                                    group_size_next       = group_size      << 1;  // group size doubles
                                    pairs_per_group_next  = pairs_per_group << 1;  // and thus number of pairs doubles
                                    a_b_gap_size_next     = a_b_gap_size    << 1;  // and so does the gap size double

                                    gbi_a_next = 0;                 // reset A base pointer
                                    gbi_b_next = a_b_gap_size_next; // reset B base pointer to the gap size
                                    gbo_a_next = gbi_a_next;        // set A offset to A base pointer
                                    gbo_b_next = gbi_b_next;        // set B offset to B base pointer
                                    
                                    if(no_of_groups < 2) begin // this means we no_of_groups is 1, FFT is done.
                                        state_next = 0;
                                        fft_done_next = 1;
                                    end
                                end
                            end
                        end
                    end 
                end
            end
        endcase

        if(rst) state_next   = 0;

    end

endmodule
