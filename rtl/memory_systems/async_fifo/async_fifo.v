// distributed under the mit license
// https://opensource.org/licenses/mit-license.php

`timescale 1 ns / 1 ps
`default_nettype none

module async_fifo

    #(
        parameter DSIZE = 8,
        parameter ASIZE = 4,
        parameter FALLTHROUGH = "TRUE", // First word fall-through without latency
        parameter SYNC_STAGES = 2
    )(
        input  wire             wclk,
        input  wire             wrst_n,
        input  wire             winc,
        input  wire [DSIZE-1:0] wdata,
        output wire             wfull,
        output wire             awfull,
        input  wire             rclk,
        input  wire             rrst_n,
        input  wire             rinc,
        output wire [DSIZE-1:0] rdata,
        output wire             rempty,
        output wire             arempty
    );

    wire [ASIZE-1:0] waddr, raddr;
    wire [ASIZE  :0] wptr, rptr, wq2_rptr, rq2_wptr;

    // The module synchronizing the read point
    // from read to write domain
    sync_ptr
    #(
    .ASIZE       (ASIZE),
    .SYNC_STAGES (SYNC_STAGES)
    )
    sync_r2w (
    .dest_ptr  (wq2_rptr),
    .src_ptr   (rptr),
    .dest_clk  (wclk),
    .dest_rst_n(wrst_n)
    );

    // The module synchronizing the write point
    // from write to read domain
    sync_ptr
    #(
    .ASIZE       (ASIZE),
    .SYNC_STAGES (SYNC_STAGES)
    )
    sync_w2r (
    .dest_ptr  (rq2_wptr),
    .src_ptr   (wptr),
    .dest_clk  (rclk),
    .dest_rst_n(rrst_n)
    );

    // The module handling the write requests
    wptr_full
    #(ASIZE)
    wptr_full (
    .awfull   (awfull),
    .wfull    (wfull),
    .waddr    (waddr),
    .wptr     (wptr),
    .wq2_rptr (wq2_rptr),
    .winc     (winc),
    .wclk     (wclk),
    .wrst_n   (wrst_n)
    );

    // The DC-RAM
    fifomem
    #(DSIZE, ASIZE, FALLTHROUGH)
    fifomem (
    .rclken (rinc),
    .rclk   (rclk),
    .rdata  (rdata),
    .wdata  (wdata),
    .waddr  (waddr),
    .raddr  (raddr),
    .wclken (winc),
    .wfull  (wfull),
    .wclk   (wclk)
    );

    // The module handling read requests
    rptr_empty
    #(ASIZE)
    rptr_empty (
    .arempty  (arempty),
    .rempty   (rempty),
    .raddr    (raddr),
    .rptr     (rptr),
    .rq2_wptr (rq2_wptr),
    .rinc     (rinc),
    .rclk     (rclk),
    .rrst_n   (rrst_n)
    );

endmodule

`resetall
