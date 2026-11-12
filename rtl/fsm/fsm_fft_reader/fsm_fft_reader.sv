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
- Must be a positive int >= 4, matching the shared FFT multiplier/adder cores.
- CYCLES_WIDTH is max(1, ceil(log2(II_CYCLES))) for a counter from 0 to II_CYCLES-1.

READ_LATENCY [>= 1, default 1]:
- Common sample/twiddle BRAM read latency, including any BRAM input/output stages.
- A command is presented after an edge and sampled by memory on the next edge.
  Its returned-data valid asserts READ_LATENCY clocks after command presentation.
- Both memories must have the same configured latency, so B and W return together
  and A returns one clock later. The valid pipelines are flushed by registered rst.
- Reads have no backpressure.

Sequencer scope:
- Generate read requests only. Stage transitions do not wait for downstream work.
- busy_o describes request generation. fft_done_o marks the end of the read
  schedule; it does not wait for returned data or arithmetic/write completion.

Runtime configuration:
- fft_point_size_i is N, a power of two >= 2, with
  N <= min(2**SAMPLES_ADDR_WIDTH, 2**(TWIDDLES_ADDR_WIDTH + 1)).
- fft_whole_iterations_i is the positive number of independent N-point FFTs in
  sample memory. Require N * fft_whole_iterations_i <= 2**SAMPLES_ADDR_WIDTH.
- Hold the configuration stable while busy_o is high. go_i is level-sensitive;
  hold it low before completion unless another run is intended.
- These are caller requirements;
  this FSM does not validate the requested sizes.

Internal widths:
- group_size includes an extra bit to represent N=2**SAMPLES_ADDR_WIDTH.
- no_of_groups, pairs_per_group, a_b_gap_size, and their pair/group counters
  need at most N/2 during an active stage. whole_counter reaches at most the
  configured whole-FFT count, which is at most 2**(SAMPLES_ADDR_WIDTH-1).
- Sample and twiddle pointers are address-width values; overflowing address bits
  are discarded. The widened group_size is not an address.
- Stage parameters advance only when another stage exists. Request spacing stays
  II_CYCLES across pair, group, whole-FFT, and stage boundaries.
- Reset remains registered: commands/valids are suppressed when rst is high.

*/

import constant_functions_pkg::*;

module fsm_fft_reader #(
    parameter DATA_WIDTH,
    parameter SAMPLES_ADDR_WIDTH,
    parameter TWIDDLES_ADDR_WIDTH,
    parameter II_CYCLES,
    parameter READ_LATENCY = 1,

    ////////////////////////////////////////////////////////////////
    // Globally Defined Locally Set Parameters
    localparam DATA_DEPTH   = bram_single_port_DATA_DEPTH(SAMPLES_ADDR_WIDTH),
    localparam CYCLES_WIDTH = fsm_fft_reader_CYCLES_WIDTH(II_CYCLES)

) (
    input                                     clk_i,
    input                                     rst_i,

    input   [SAMPLES_ADDR_WIDTH : 0]          fft_point_size_i,
    input   [SAMPLES_ADDR_WIDTH - 1 : 0]      fft_whole_iterations_i,

    input                                     go_i,

    output  [SAMPLES_ADDR_WIDTH - 1 : 0]      a_b_rd_addr_o,
    output                                    a_b_rd_en_o,
    output                                    a_valid_o,
    output                                    b_valid_o,

    output  [TWIDDLES_ADDR_WIDTH - 1 : 0]     w_rd_addr_o,
    output                                    w_rd_en_o,
    output                                    w_valid_o,
    output                                    busy_o,
    output                                    fft_done_o

);

    // Unconditional input register stage, including reset.
    logic                                     rst;
    logic   [SAMPLES_ADDR_WIDTH : 0]          fft_point_size;
    logic   [SAMPLES_ADDR_WIDTH - 1 : 0]      fft_whole_iterations;        // how many N-point FFTs to process in the Sample space
    logic                                     go;

    // Current values.
    typedef enum logic {IDLE_RESET, RUNNING} state_t;
    state_t                                   state;
    logic   [SAMPLES_ADDR_WIDTH - 1 : 0]      gbi_a;                       // 'gbi' stands for group base index
    logic   [SAMPLES_ADDR_WIDTH - 1 : 0]      gbo_a;                       // 'gbo' stands for group base offset
    logic   [SAMPLES_ADDR_WIDTH - 1 : 0]      gbi_b;
    logic   [SAMPLES_ADDR_WIDTH - 1 : 0]      gbo_b;
    logic   [TWIDDLES_ADDR_WIDTH - 1 : 0]     tbo_w;                       // 'tbo' stands for twiddle base offset
    logic   [SAMPLES_ADDR_WIDTH : 0]          group_size;                  // up to N, including the full memory depth
    logic   [SAMPLES_ADDR_WIDTH - 1 : 0]      a_b_gap_size;                // gap between A, B base addresses, starts at 1
    logic   [SAMPLES_ADDR_WIDTH - 1 : 0]      no_of_groups;                // groups in a given stage in an N-point FFT, starts at N/2
    logic   [SAMPLES_ADDR_WIDTH - 1 : 0]      pairs_per_group;             // pairs per group in a given stage, starts at 1

    logic   [SAMPLES_ADDR_WIDTH - 1 : 0]      pair_counter;                // pair counter
    logic   [SAMPLES_ADDR_WIDTH - 0 : 0]      group_counter;               // group counter
    logic   [SAMPLES_ADDR_WIDTH - 1 : 0]      whole_counter;               // counts fft whole iterations
    logic   [CYCLES_WIDTH - 1 : 0]            cycles_counter;              // cycle counter to wait after both b/w then a reads are ushered

    logic                                     a_bw_toggle;                 // b/w or a read being ushered?
    logic   [1:0]                             a_bw_done;                   // both b/w and a done, need 2-bits to separate idle/transmission

    logic                                     fft_done;

    logic                                     usher_a;
    logic   [SAMPLES_ADDR_WIDTH - 1 : 0]      usher_a_addr;

    logic                                     usher_b;
    logic   [SAMPLES_ADDR_WIDTH - 1 : 0]      usher_b_addr;

    logic                                     usher_w;
    logic   [TWIDDLES_ADDR_WIDTH - 1 : 0]     usher_w_addr;

    // Corresponding next values
    state_t                                   state_next;
    logic   [SAMPLES_ADDR_WIDTH - 1 : 0]      gbi_a_next;
    logic   [SAMPLES_ADDR_WIDTH - 1 : 0]      gbo_a_next;
    logic   [SAMPLES_ADDR_WIDTH - 1 : 0]      gbi_b_next;
    logic   [SAMPLES_ADDR_WIDTH - 1 : 0]      gbo_b_next;
    logic   [TWIDDLES_ADDR_WIDTH - 1 : 0]     tbo_w_next;
    logic   [SAMPLES_ADDR_WIDTH : 0]          group_size_next;
    logic   [SAMPLES_ADDR_WIDTH - 1 : 0]      a_b_gap_size_next;
    logic   [SAMPLES_ADDR_WIDTH - 1 : 0]      no_of_groups_next;
    logic   [SAMPLES_ADDR_WIDTH - 1 : 0]      pairs_per_group_next;

    logic   [SAMPLES_ADDR_WIDTH - 1 : 0]      pair_counter_next;
    logic   [SAMPLES_ADDR_WIDTH - 0 : 0]      group_counter_next;
    logic   [SAMPLES_ADDR_WIDTH - 1 : 0]      whole_counter_next;
    logic   [CYCLES_WIDTH - 1 : 0]            cycles_counter_next;

    logic                                     a_bw_toggle_next;
    logic   [1:0]                             a_bw_done_next;

    logic                                     fft_done_next;

    logic                                     usher_a_next;
    logic   [SAMPLES_ADDR_WIDTH - 1 : 0]      usher_a_addr_next;

    logic                                     usher_b_next;
    logic   [SAMPLES_ADDR_WIDTH - 1 : 0]      usher_b_addr_next;

    logic                                     usher_w_next;
    logic   [TWIDDLES_ADDR_WIDTH - 1 : 0]     usher_w_addr_next;

    always @(posedge clk_i) begin
        rst                    <= rst_i;
        fft_point_size         <= fft_point_size_i;
        fft_whole_iterations   <= fft_whole_iterations_i;
        go                     <= go_i;

        state                  <= state_next;
        gbi_a                  <= gbi_a_next;
        gbo_a                  <= gbo_a_next;
        gbi_b                  <= gbi_b_next;
        gbo_b                  <= gbo_b_next;
        tbo_w                  <= tbo_w_next;
        group_size             <= group_size_next;
        a_b_gap_size           <= a_b_gap_size_next;
        no_of_groups           <= no_of_groups_next;
        pairs_per_group        <= pairs_per_group_next;

        pair_counter           <= pair_counter_next;
        group_counter          <= group_counter_next;
        whole_counter          <= whole_counter_next;
        cycles_counter         <= cycles_counter_next;

        a_bw_toggle            <= a_bw_toggle_next;
        a_bw_done              <= a_bw_done_next;

        fft_done               <= fft_done_next;

        usher_a                <= usher_a_next;
        usher_a_addr           <= usher_a_addr_next;

        usher_b                <= usher_b_next;
        usher_b_addr           <= usher_b_addr_next;

        usher_w                <= usher_w_next;
        usher_w_addr           <= usher_w_addr_next;
    end

    // One shared sample read port; both A/B command addresses are already registered.
    assign a_b_rd_addr_o = usher_a ? usher_a_addr : usher_b_addr;
    assign a_b_rd_en_o = (usher_a || usher_b) && !rst;
    assign w_rd_addr_o = usher_w_addr;
    assign w_rd_en_o = usher_w && !rst;
    assign busy_o = (state != IDLE_RESET) && !rst;
    assign fft_done_o = fft_done && !rst;

    logic [READ_LATENCY - 1 : 0] a_valid, b_valid, w_valid;
    always @(posedge clk_i) begin
        if(rst) begin
            a_valid                <= '0;
            b_valid                <= '0;
            w_valid                <= '0;
        end else begin
            a_valid[0] <= usher_a;
            b_valid[0] <= usher_b;
            w_valid[0] <= usher_w;
            for(int i = 1; i < READ_LATENCY; i++) begin
                a_valid[i] <= a_valid[i - 1];
                b_valid[i] <= b_valid[i - 1];
                w_valid[i] <= w_valid[i - 1];
            end
        end
    end
    assign a_valid_o = a_valid[READ_LATENCY - 1] && !rst;
    assign b_valid_o = b_valid[READ_LATENCY - 1] && !rst;
    assign w_valid_o = w_valid[READ_LATENCY - 1] && !rst;

    initial begin
        if(SAMPLES_ADDR_WIDTH < 1 || SAMPLES_ADDR_WIDTH > 30)
            $fatal(1, "SAMPLES_ADDR_WIDTH must be 1..30 with the int DATA_DEPTH helper");
        if(TWIDDLES_ADDR_WIDTH < 1) $fatal(1, "TWIDDLES_ADDR_WIDTH must be positive");
        if(II_CYCLES < 4) $fatal(1, "II_CYCLES must be at least 4 for the shared FFT cores");
        if(READ_LATENCY < 1) $fatal(1, "READ_LATENCY must be positive");
    end

    always_comb begin
        // Hold defaults also cover an unknown/illegal state without inferring latches.
        state_next             = state;
        gbi_a_next             = gbi_a;
        gbo_a_next             = gbo_a;
        gbi_b_next             = gbi_b;
        gbo_b_next             = gbo_b;
        tbo_w_next             = tbo_w;
        group_size_next        = group_size;
        a_b_gap_size_next      = a_b_gap_size;
        no_of_groups_next      = no_of_groups;
        pairs_per_group_next   = pairs_per_group;
        pair_counter_next      = pair_counter;
        group_counter_next     = group_counter;
        whole_counter_next     = whole_counter;
        cycles_counter_next    = cycles_counter;
        a_bw_toggle_next       = a_bw_toggle;
        a_bw_done_next         = a_bw_done;
        fft_done_next          = 0;
        // regardless defaults
        usher_a_next           = 0;
        usher_a_addr_next      = gbo_a;

        usher_b_next           = 0;
        usher_b_addr_next      = gbo_b;

        usher_w_next           = 0;
        usher_w_addr_next      = tbo_w;

        case (state)
            IDLE_RESET: begin
                // defaults
                gbi_a_next             = 0;
                gbo_a_next             = 0;
                gbi_b_next             = 1; // default of a_b_gap_size.
                gbo_b_next             = 1;
                tbo_w_next             = 0;

                no_of_groups_next      = fft_point_size >> 1;
                pairs_per_group_next   = 1;
                group_size_next        = 2;
                a_b_gap_size_next      = 1;

                pair_counter_next      = 0;
                group_counter_next     = 0;
                whole_counter_next     = 0;
                cycles_counter_next    = 0;

                a_bw_toggle_next       = 1; // we start with b and w
                a_bw_done_next         = 0;

                fft_done_next          = 0;

                state_next             = IDLE_RESET;
                if(go)  state_next     = RUNNING;
            end

            RUNNING: begin
                // Advance the issue interval; the remaining state holds by default.
                cycles_counter_next    = cycles_counter + 1;
                a_bw_done_next         = 0;

                if(a_bw_toggle) begin // toggle starts 1'b1 -> b/w read first
                    usher_b_next           = 1;
                    usher_w_next           = 1;
                    a_bw_toggle_next       = 0;
                    a_bw_done_next         = 2'b01;
                end else begin
                    if(a_bw_done == 2'b01) begin // 2-bit a_bw_done, to separate a usher from idle cycles
                        usher_a_next           = 1;
                        a_bw_done_next         = 2'b11;
                    end
                    if(cycles_counter >= (II_CYCLES - 1)) begin
                        cycles_counter_next    = 0; // reset cycle counter

                        a_bw_done_next         = 0; // reset done from 2'b11
                        a_bw_toggle_next       = 1; // reset toggle back to bw

                        gbo_a_next             = gbo_a + 1; // increment A offset
                        gbo_b_next             = gbo_b + 1; // increment B offset

                        pair_counter_next      = pair_counter + 1;
                        tbo_w_next             = tbo_w + no_of_groups; // advance k by G for each pair
                        if(pair_counter_next >= pairs_per_group) begin // finished group
                            pair_counter_next      = 0; // reset pair counter
                            tbo_w_next             = 0;        // repeat the twiddle sequence for each group

                            gbi_a_next             = gbi_a + group_size;   // increment A base pointer using group size
                            gbi_b_next             = gbi_b + group_size;   // incrememt B base pointer using group size
                            gbo_a_next             = gbi_a_next;           // set A offset to A base pointer
                            gbo_b_next             = gbi_b_next;           // set B offset to B base pointer

                            group_counter_next     = group_counter + 1;
                            if(group_counter_next >= no_of_groups) begin // finished all groups in N-point FFT
                                group_counter_next     = 0; // reset group counter

                                tbo_w_next             = 0; // unlike the gbi/o_* variables, which tile over correctly
                                                        // we need to reset the twiddle base between successive N-point FFTs.

                                whole_counter_next     = whole_counter + 1;
                                if(whole_counter_next >= fft_whole_iterations) begin // finished all groups across all N-point FFT tiled over the Sample Space
                                    whole_counter_next     = 0; // reset whole counter

                                    if(no_of_groups == 1) begin
                                        state_next             = IDLE_RESET;
                                        fft_done_next          = 1;
                                    end else begin
                                        no_of_groups_next      = no_of_groups >> 1;
                                        group_size_next        = group_size << 1;
                                        pairs_per_group_next   = pairs_per_group << 1;
                                        a_b_gap_size_next      = a_b_gap_size << 1;
                                        gbi_a_next             = 0;
                                        gbi_b_next             = a_b_gap_size_next;
                                        gbo_a_next             = gbi_a_next;
                                        gbo_b_next             = gbi_b_next;
                                        tbo_w_next             = 0;
                                    end
                                end
                            end
                        end
                    end
                end
            end

            default: state_next = IDLE_RESET;
        endcase

        if(rst) begin
            state_next             = IDLE_RESET;
            usher_a_next           = 0;
            usher_b_next           = 0;
            usher_w_next           = 0;
            fft_done_next          = 0;
        end

    end

endmodule
