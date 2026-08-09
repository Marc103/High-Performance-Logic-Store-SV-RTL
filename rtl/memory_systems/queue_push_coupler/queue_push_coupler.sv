/*
Queue Push Coupler.
Exposes ready/burstready/valid interface on the push side (write side)
of a queue. Designed to work with 'queue' or 'queue_async'.

DATA_WIDTH:
- Data width.

SIMPLE [0,1]:
- With SIMPLE enabled, the 'push_i' into the queue is simply wired to 'valid_i'
  and 'ready_o' is wired to '!full_o' of the queue. Whilst simple, the long
  combinatorial logic prevents high clock rates.

- With SIMPLE enabled, BURST_SIZE > 1 is not possible with ASYNC enabled,
  because our current queue_async implementation only supplies one entry lookahead.
  Instead, SIMPLE must be disabled, and thus a reservoir is used. If this is misconfigured,
  burstready is simple set to 0.

- With SIMPLE disabled, a minimum 3-entry 'reservoir' is also instantiated, allowing
  for valid data to be recieved on the cycle it is ushered, provides the necessary
  lookahead to correctly control the push_i signal and in the process, breaks
  up the logic allowing for a completely clean (free of logic) push_i signal into
  the queue, solving the main issue with the simple model.

ASYNC [0, 1]:
- Is the queue that this would be attached to asynchronous?

BURST_SIZE [1, 2 ** ADDR_WIDTH]:
- Burst ready burst size.

ADDR_WIDTH:
- What is the address width of the queue that this will be attached to?

*/

import constant_functions_pkg::*;

module queue_push_coupler #(
    parameter DATA_WIDTH,
    parameter SIMPLE,
    parameter ASYNC,
    parameter BURST_SIZE,
    parameter ADDR_WIDTH,

    ////////////////////////////////////////////////////////////////
    // Globally Defined Locally Set Parameters
    localparam RESERVOIR_BACKPRESSURE_ENTRIES = queue_push_coupler_RESERVOIR_BACKPRESSURE_ENTRIES(BURST_SIZE),
    localparam DATA_DEPTH                     = queue_DATA_DEPTH(ADDR_WIDTH)
) (
    input wr_clk_i,
    input wr_rst_i,

    // fill side
    input [DATA_WIDTH - 1 : 0] wr_data_i,
    input                      wr_valid_i,
    output                     ready_o,
    output                     burstready_o,

    // drain side / queue side
    input full_i,
    input lookahead_i,

    output [DATA_WIDTH - 1 : 0] wr_data_o,
    output                      push_o,
    output [ADDR_WIDTH : 0]     more_than_or_eq_o
);


    // Fill side
    logic                     fill_ready_o;

    // Drain side
    logic [DATA_WIDTH - 1 : 0] drain_data_o;
    logic                      drain_valid_o;
    logic                      drain_burstmark_o;

    // control state
    logic queue_push;
    logic queue_push_next;

    logic reservoir_at_least_two_left;
    logic reservoir_one_left;

    assign reservoir_at_least_two_left = drain_burstmark_o; // BURSTMARK == 2
    assign reservoir_one_left          = (!drain_burstmark_o) & drain_valid_o;

    // More than equal to DATA_DEPTH - 1, aka at most one space left
    // but if SIMPLE is enabled, we set it to DATA_DEPTH - BURST_SIZE + 1 in case
    // it can be directly used with the synchronous queue.
    assign more_than_or_eq_o = (SIMPLE == 1) ? DATA_DEPTH - BURST_SIZE + 1 : DATA_DEPTH - 1;

    // Reservoir Instantiation or if SIMPLE enabled direct wiring
    generate
        if(SIMPLE == 1) begin
            assign ready_o = !full_i;
            assign burstready_o = (ASYNC == 1)
                ? ((BURST_SIZE == 1) ? !full_i : 1'b0)
                : !lookahead_i;

            assign wr_data_o    = wr_data_i;
            assign push_o       = wr_valid_i & (!full_i);
        end else begin
            reservoir #(
                .DATA_WIDTH(DATA_WIDTH),
                .WATERMARK_ENTRIES(3),
                .BACKPRESSURE_ENTRIES(RESERVOIR_BACKPRESSURE_ENTRIES),
                .BURSTMARK(2)
            ) push_coupler (
                .clk_i(wr_clk_i),
                .rst_i(wr_rst_i),

                .fill_data_i (wr_data_i),
                .fill_valid_i(wr_valid_i),
                .fill_ready_o(fill_ready_o),

                .drain_ready_i(queue_push),
                .drain_data_o(wr_data_o),
                .drain_valid_o(drain_valid_o),
                .drain_burstmark_o(drain_burstmark_o)
            );

            assign ready_o      = fill_ready_o;
            assign burstready_o = fill_ready_o;

            assign push_o = queue_push;
        end
    endgenerate

    // if ASYNC == 1, the lookahead_i condition means 'one space left'
    // else         , the lookahead_i condition means 'one space left or full'
    /*
    This logic is equivalent for the cases
        1. (!full_i) & (!lookahead_i) - Not full, more than one space left
        2. (!full_i) & lookahead_i    - Not full, but one space left
    and differs for
        3. (full & (!lookahead_i))
            - the ASYNC meaning is - Full and not one space left,
            - the SYNC meaning is - Full and not at most one space left, not possible
        4. (full & lookahead_i)
            - the ASYNC meaning - Full and one space left, not possible
            - the SYNC meaning - Full and at most one space left
    - but this is not an issue, as we don't need cases 3. and 4. to make our decisions anyway
    */

    always_comb begin
        if((!full_i) & (!lookahead_i))          // Not full, more than one space left

            if(reservoir_at_least_two_left) begin // reservoir two left
                if(queue_push) begin // already about to queue_push
                    queue_push_next = 1;
                end else begin
                    queue_push_next = 1;
                end

            end else if (reservoir_one_left) begin // reservoir one left
                if(queue_push) begin // already about to queue_push
                    queue_push_next = 0;
                end else begin
                    queue_push_next = 1;
                end

            end else begin                         // reservoir empty
                if(queue_push) begin // already about to queue_push, this shouldn't be reachable by prior logic
                    queue_push_next = 0;
                end else begin
                    queue_push_next = 0;
                end
            end

        else if((!full_i) & lookahead_i) begin // Not full, but one space left

            if(reservoir_at_least_two_left) begin // reservoir two left
                if(queue_push) begin // already about to queue_push
                    queue_push_next = 0;
                end else begin
                    queue_push_next = 1;
                end

            end else if (reservoir_one_left) begin // reservoir one left
                if(queue_push) begin // already about to queue_push
                    queue_push_next = 0;
                end else begin
                    queue_push_next = 1;
                end

            end else begin                         // reservoir empty
                if(queue_push) begin // already about to queue_push, this shouldn't be reachable by prior logic
                    queue_push_next = 0;
                end else begin
                    queue_push_next = 0;
                end
            end

        end else begin                       // Full
            queue_push_next = 0;
        end

        if(wr_rst_i) begin
            queue_push_next = 0;
        end
    end

    always@(posedge wr_clk_i) begin
        queue_push <= queue_push_next;
    end

endmodule
