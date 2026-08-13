/*
Reservoir No Backpressure, a ready/valid fifo cache that does not accept backpressure.

The workings are the same as 'reservoir' with a key difference: Valids presented when
the reservoir is not ready will not be consumed into backpressure entries. This new
behavior is necessary to fulfill the traditional 'valid & ready' protocol.

So both reservoir and reservoir_no_backpressure have their respective use cases,
be weary of the difference.

--- Definitions ---------------------------------------------------------------------------------------------
'spool up' cycles: Minimum number of cycles it takes from the cycle that the 'fill_ready_o' is asserted
for upstream logic to provide data.

'spool down' cycles: Maximum additional number of cycles it takes from the cycle that the 'fill_ready_o' is
deasserted for upstream logic to stop providing data.

This includes burst size coming from upstream. I.e. +1 'reaction' cycles of stop signal to reach but
upstream burst size is 4, so worst case is we need 4 backpressure entries. However, if it's the case that the
reaction is so slow that a secondary burst from upstream could be triggered, the appropriate formula is
(reaction / upstream burst size + upstream burst size), using floor division.
If during the reaction time, single items could be issued before the final late one ushers a burst, then add
an additional (reaction - 1) backpressure entries, making the safest calculation
(reaction / upstream burst size + upstream burst size + reaction - 1).

-------------------------------------------------------------------------------------------------------------

DATA_WIDTH:
- Data width.

WATERMARK_ENTRIES [2, ..]:
- How many watermark entries? To enable optimal continous burst stream, set to at least (minimum is 2):

FILLMARK[1, WATERMARK_ENTRIES]:
- What is your upstream burst size? This tell upstream logic wheter FILLMARK entires are available to be
  filled with. Must be smaller than or equal to WATERMARK_ENTRIES.

BURSTMARK[1, WATERMARK_ENTRIES]:
- What is your downstream burst size? Must be smaller than or equal to WATERMARK_ENTRIES.

*/

import constant_functions_pkg::*;

module reservoir_no_backpressure #(
    parameter DATA_WIDTH,
    parameter WATERMARK_ENTRIES,
    parameter FILLMARK,
    parameter BURSTMARK,

    ////////////////////////////////////////////////////////////////
    // Globally Defined Locally Set Parameters
    localparam ENTRIES = reservoir_ENTRIES(WATERMARK_ENTRIES, 0)
) (
    input clk_i,
    input rst_i,

    // Fill side
    input [DATA_WIDTH - 1 : 0] fill_data_i,
    input                      fill_valid_i,

    output                     fill_ready_o,
    output                     fill_burstready_o,

    // Drain side
    input                       drain_ready_i,

    output [DATA_WIDTH - 1 : 0] drain_data_o,
    output                      drain_valid_o,
    output                      drain_burstmark_o
);

    logic [ENTRIES - 1 : 0][DATA_WIDTH - 1 : 0] reservoir;
    logic [ENTRIES - 1 : 0][DATA_WIDTH - 1 : 0] reservoir_next;
    logic [ENTRIES - 1 : 0]                     reservoir_ce;

    logic [ENTRIES - 1 : 0] occupied;
    logic [ENTRIES - 1 : 0] occupied_next;
    logic [ENTRIES - 1 : 0] occupied_ce;

    logic [ENTRIES - 1 : 0] bottom_most_free;
    logic [ENTRIES - 1 : 0] top_most_occupied;

    logic fill;
    logic drain;

    always@(posedge clk_i) begin
        for(int i = 0; i < ENTRIES; i++) begin
            if(reservoir_ce[i]) begin
                reservoir[i] <= reservoir_next[i];
            end else begin
                reservoir[i] <= reservoir[i];
            end

            if(occupied_ce[i]) begin
                occupied[i] <= occupied_next[i];
            end else begin
                occupied[i] <= occupied[i];
            end
        end
    end

    // Can't fill when reservoir is full
    assign fill = fill_valid_i & (!occupied[0]);
    // can't drain if the reservoir is empty.
    assign drain = occupied[ENTRIES - 1] & drain_ready_i;

    always_comb begin
        // determine the bottom most free, used for (fill, !drain)
            // if:
            // unoccupied and most bottom entry (index [ENTRIES - 1])
            // else:
            // unoccupied and just below is occupied
        for(int i = 0; i < ENTRIES; i++) begin
            if(i == (ENTRIES - 1)) begin
                bottom_most_free[i] = !occupied[i];
            end else begin
                bottom_most_free[i] = (!occupied[i]) & occupied[i + 1];
            end
        end

        // determine the top most occupied, used for simultaneous Fill & Drain
            // if:
            // occupied and top most entry (index [0])
            // else:
            // occupied and just above is unoccupied
        for(int i = 0; i < ENTRIES; i++) begin
            if(i == 0) begin
                top_most_occupied[i] = occupied[i];
            end else begin
                top_most_occupied[i] = occupied[i] & (!occupied[i - 1]);
            end
        end

        // CE value,
        // if draining everything gets active
        // otherwise, in the case of just fill, only bottom_most_free gets active
        for(int i = 0; i < ENTRIES; i++) begin
            reservoir_ce[i] = drain | (fill & bottom_most_free[i]);
            occupied_ce[i]  = drain | (fill & bottom_most_free[i]) | rst_i;
        end

        // Mux Selector
        for(int i = 0; i < ENTRIES; i++) begin
            // default, point to above entry, with exception to the top
            // most entry, which points to fill_data_i
            if(i == 0) begin
                reservoir_next[i] = fill_data_i;
                occupied_next[i]  = 0;
            end else begin
                reservoir_next[i] = reservoir[i - 1];
                occupied_next[i]  = occupied[i - 1];
            end

            // We only need to change if Fill is active, so we look at
                // fill & (!drain) - bottom most free gets fill_data_i and occupied next set to 1
                // fill & drain    - preemptive bottom most free gets fill_data_i and occupied next set to 1
            if(fill & (!drain)) begin         // Fill Only
                if(bottom_most_free[i]) begin
                    reservoir_next[i] = fill_data_i;
                    occupied_next[i] = fill_valid_i;
                end
            end else if (fill & drain) begin // Fill & Drain
                if(top_most_occupied[i]) begin
                    reservoir_next[i] = fill_data_i;
                    occupied_next[i] = fill_valid_i;
                end
            end
        end

        // reset, clear occupied flags.
        if(rst_i) begin
            for(int i = 0; i < ENTRIES; i++) begin
                occupied_next[i] = 0;
            end
        end
    end

    assign fill_ready_o = !occupied[ENTRIES - WATERMARK_ENTRIES];
    assign fill_burstready_o = !occupied[FILLMARK - 1];

    assign drain_data_o      = reservoir[ENTRIES - 1];
    assign drain_valid_o     = occupied[ENTRIES - 1];
    assign drain_burstmark_o = occupied[ENTRIES - BURSTMARK];

endmodule
