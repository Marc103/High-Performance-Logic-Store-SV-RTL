/*
Reservoir, a ready/valid fifo cache.

--- Definitions ---------------------------------------------------------------------------------------------
'spool up' cycles: Minimum number of cycles it takes from the cycle that the 'fill_ready_o' is asserted
for upstream logic to provide data.

'spool down' cycles: Maximum number of cycles it takes from the cycle that the 'fill_ready_o' is deasserted
for upstream logic to stop providing data.
-------------------------------------------------------------------------------------------------------------

There are 3 issues that this module solves:
1. Zero latency reaction: Data buffered in the reservoir is immediately available to the consumer
    - The issue is caused by stall bubbles of upstream logic due to spool up cycles
2. Handles backpressure: Late arriving data is buffered in BACK_PRESSURE_ENTRIES
    - The issue is caused by upstream logic that has spool up and spool down cycles
3. Continous burst mode management
    - Using 'drain_burstmark_o', downstream logic can know if at at least BURSTMARK entries
      are available for consumption.

It works like a water tank (hence reservoir) and functionally like a FIFO but without explicit read/write pointers.
New entries fall to the bottom most unoccupied entry, then the bottom most entry is exposed to the consumer. The reservoir
will assert 'fill_ready_o' until at least WATERMARK_ENTRIES are present, then we rely on the BACKPRESSURE_ENTRIES to handle
backpressure.

DATA_WIDTH:
- Data width.

WATERMARK_ENTRIES [2, ..]:
- How many watermark entries? To enable optimal continous burst stream, set to at least (minimum is 2):
   -------------------------------------
   | (spool up cycles + 1 + BURSTMARK) |
   -------------------------------------
- Setting it less than the optimal costs an initial stall bubble reaction time delay, which may or may not
  be good enough depending on the application.

BACKPRESSURE_ENTRIES [0, ..]:
- How many backpressure entries? Must be set to (minimum is 0):
   ---------------------------------------------
   | (spool up cycles + spool down cycles - 1) |
   ---------------------------------------------

BURSTMARK[1, WATERMARK_ENTRIES]:
- What is your burst size? Must be smaller than or equal to WATERMARK_ENTRIES.

////////////////////////////////////////////////////////////////
// An Example Setup

spool up cycles = 2
spool down cycles = 1
burst size = 1
therefore,
BURSTMARK            = burst size = 1
WATER_ENTRIES        = 2 + 1 + 1 = 4  *optimal configuration
BACKPRESSURE_ENTRIES = 2 + 1 - 1 = 2

-------------- BACKPRESSURE_ENTRIES = 2
[-] - top entry is the 'top' of the reservoir, exists at index [0]
[-]
-------------- WATERMARK_ENTRIES = 4
[-]
[-]
[-]
-------------- BURSTMARK = 1
[-] - bottom entry is the 'bottom' of the reservoir, exists at index [ENTRIES - 1]

* ENTRIES = WATERMARK_ENTRIES + BACKPRESSURE_ENTRIES;

////////////////////////////////////////////////////////////////
// Limitations

1. Summary: if the spool up and spool down times can't be effectively ammortized by active times,
            the effectiveness of this module is also reduced.

2. The number of fanout points of the 'fill_data_i' is the total entries, and the worst-case length fanout is
   proportional to the (total entries x DATA_WIDTH). So this needs to be kept in mind.

3. More efficient ways are available for large continous burst sizes if the upstream logic exposes at least two
   programmable occupancy level flags but wil introduce < 100% duty cycle if we need to support both continous
   burst and single consumption (i.e to prevent impartial burst from being 'stuck')

1. Intermittent upstream data arriving and low latency requirements. Say the producer produces data very sparsely
   but we wish the consumer to react in zero cycles.
    a. Synchronous case: If this is truly the behavior required then why have a buffer at all? And if you still need
       a buffer (i.e sometimes along the sparse activity we get bursts that the consumer can't keep up with), then
       what you need is a first-word fall-through (FTWT) fifo with the control signals directly wired to read/write logic.
       Unfortunately, the long combinatorial logic paths of the control signals slow down the clock signficantly and 
       there are no RTL level logic optimizations to solve this on FPGAs. Well actually there is, which is to make 
       the buffer very shallow (i.e 4/8 entries corresponds to 2/3 bit width addresses) and so if your use case is such 
       then that is what I would recommend; in that case such a module 'queue_zero_latency' will be developed.
    b. Asynchronous case: The latency caused by the synchronization flip-flops stages inherently prohibits (at least to
       the best of my knowledge) zero latency requirements (especially at very high clock rates, where three stages would 
       be necessary to meet suitable metastability MTBF), and I highly doubt that trying to minimize the latency is worth 
       the diminshed clock rates.
*/

import constant_functions_pkg::*;

module reservoir #(
    parameter DATA_WIDTH,
    parameter WATERMARK_ENTRIES,
    parameter BACKPRESSURE_ENTRIES,
    parameter BURSTMARK,

    ////////////////////////////////////////////////////////////////
    // Globally Defined Locally Set Parameters
    localparam ENTRIES = reservoir_ENTRIES(WATERMARK_ENTRIES, BACKPRESSURE_ENTRIES)
) (
    input clk_i,
    input rst_i,

    // Fill side
    input [DATA_WIDTH - 1 : 0] fill_data_i,
    input                      fill_valid_i,

    output                     fill_ready_o,

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

    // assumes BACKPRESSURE_ENTRIES sufficiently large enough to handle backpressure.
    assign fill = fill_valid_i;
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

    assign drain_data_o      = reservoir[ENTRIES - 1];
    assign drain_valid_o     = occupied[ENTRIES - 1];
    assign drain_burstmark_o = occupied[ENTRIES - BURSTMARK];

endmodule
