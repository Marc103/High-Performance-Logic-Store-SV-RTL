// distributed under the mit license
// https://opensource.org/licenses/mit-license.php

`timescale 1 ns / 1 ps
`default_nettype none

module sync_ptr

    #(
    parameter ASIZE       = 4,
    parameter SYNC_STAGES = 2 // Must be at least 1; use 2 or more for CDC
    )(
    input  wire              dest_clk,
    input  wire              dest_rst_n,
    input  wire [ASIZE:0] src_ptr,
    output wire [ASIZE:0] dest_ptr
    );

    reg [ASIZE:0] sync_pipe [0:SYNC_STAGES-1];
    integer stage;

    assign dest_ptr = sync_pipe[SYNC_STAGES-1];

    always @(posedge dest_clk or negedge dest_rst_n) begin

        if (!dest_rst_n) begin
            for (stage = 0; stage < SYNC_STAGES; stage = stage + 1)
                sync_pipe[stage] <= 0;
        end else begin
            sync_pipe[0] <= src_ptr;
            for (stage = 1; stage < SYNC_STAGES; stage = stage + 1)
                sync_pipe[stage] <= sync_pipe[stage-1];
        end
    end

endmodule

`resetall
