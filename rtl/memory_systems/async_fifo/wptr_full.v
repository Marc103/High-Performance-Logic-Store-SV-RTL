// distributed under the mit license
// https://opensource.org/licenses/mit-license.php

`timescale 1 ns / 1 ps
`default_nettype none

module wptr_full

	#(
		parameter ADDRSIZE = 4
	)(
		input  wire                wclk,
		input  wire                wrst_n,
		input  wire                winc,
		input  wire [ADDRSIZE  :0] wq2_rptr,
		output wire                wfull,
		output wire                awfull,
		output wire [ADDRSIZE-1:0] waddr,
		output reg  [ADDRSIZE  :0] wptr
	);

    reg  [ADDRSIZE:0] wbin;
    reg  [ADDRSIZE:0] wq3_rptr;
    reg  [ADDRSIZE:0] wgrayp1;
    wire [ADDRSIZE:0] wgraynext, wgraynextp1, wbinnext;
    wire [ADDRSIZE:0] wfull_target;

	// GRAYSTYLE2 pointer
	always @(posedge wclk or negedge wrst_n) begin

		if (!wrst_n) begin
			{wbin, wptr, wq3_rptr} <= 0;
			wgrayp1 <= {{ADDRSIZE{1'b0}}, 1'b1};
		end else begin
			{wbin, wptr, wq3_rptr} <= {wbinnext, wgraynext, wq2_rptr};
			wgrayp1 <= wgraynextp1;
		end

	end

    // Memory write-address pointer (okay to use binary to address memory)
    assign waddr = wbin[ADDRSIZE-1:0];
    assign wbinnext    = wbin + ((winc & ~wfull) ? 1 : 0);
    assign wgraynext   = (wbinnext >> 1) ^ wbinnext;
    assign wgraynextp1 = ((wbinnext + 1'b1) >> 1) ^ (wbinnext + 1'b1);

    //------------------------------------------------------------------
    // Simplified version of the three necessary full-tests:
    // assign wfull_val=((wgnext[ADDRSIZE] !=wq2_rptr[ADDRSIZE] ) &&
    //                   (wgnext[ADDRSIZE-1]  !=wq2_rptr[ADDRSIZE-1]) &&
    // (wgnext[ADDRSIZE-2:0]==wq2_rptr[ADDRSIZE-2:0]));
    //------------------------------------------------------------------

     // The synchronized read pointer is delayed alongside the local pointer
     // so these post-register comparisons retain the original cycle alignment.
     assign wfull_target = {~wq3_rptr[ADDRSIZE:ADDRSIZE-1],wq3_rptr[ADDRSIZE-2:0]};
     assign wfull  = (wptr    == wfull_target);
     assign awfull = (wgrayp1 == wfull_target);

endmodule

`resetall
