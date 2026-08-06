// distributed under the mit license
// https://opensource.org/licenses/mit-license.php

`timescale 1 ns / 1 ps
`default_nettype none

module rptr_empty

    #(
    parameter ADDRSIZE = 4
    )(
    input  wire                rclk,
    input  wire                rrst_n,
    input  wire                rinc,
    input  wire [ADDRSIZE  :0] rq2_wptr,
    output wire                rempty,
    output wire                arempty,
    output wire [ADDRSIZE-1:0] raddr,
    output reg  [ADDRSIZE  :0] rptr
    );

    reg  [ADDRSIZE:0] rbin;
    reg  [ADDRSIZE:0] rq3_wptr;
    reg  [ADDRSIZE:0] rgrayp1;
    wire [ADDRSIZE:0] rgraynext, rgraynextp1;
    wire [ADDRSIZE:0] rbinnext, rbinp1next;

    //-------------------
    // GRAYSTYLE2 pointer
    //-------------------
    always @(posedge rclk or negedge rrst_n) begin

        if (!rrst_n) begin
            {rbin, rptr, rq3_wptr} <= 0;
            rgrayp1 <= {{ADDRSIZE{1'b0}}, 1'b1};
        end else begin
            {rbin, rptr, rq3_wptr} <= {rbinnext, rgraynext, rq2_wptr};
            rgrayp1 <= rgraynextp1;
        end

    end

    // Memory read-address pointer (okay to use binary to address memory)
    // The caller must not assert rinc while rempty is high.
    assign raddr       = rbin[ADDRSIZE-1:0];
    assign rbinnext    = rbin + (rinc ? 1 : 0);
    assign rbinp1next  = rbin + (rinc ? 2 : 1);
    assign rgraynext   = (rbinnext >> 1) ^ rbinnext;
    assign rgraynextp1 = (rbinp1next >> 1) ^ rbinp1next;

    //---------------------------------------------------------------
    // FIFO empty when rptr == the aligned synchronized wptr.
    // The comparison is intentionally placed after the pointer registers.
    //---------------------------------------------------------------
    assign rempty  = (rptr    == rq3_wptr);
    assign arempty = (rgrayp1 == rq3_wptr);

endmodule

`resetall
