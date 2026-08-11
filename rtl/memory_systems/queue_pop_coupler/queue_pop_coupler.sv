/*
Queue Pop Coupler.
Exposes a valid/burstvalid/ready interface on the pop side (read side)
of a queue. Designed to work with 'queue' or 'queue_async'.

DATA_WIDTH:
- Data width.

ADDR_WIDTH:
- What is the address width of the queue that this will be attached to?

ASYNC [0, 1]:
- Is the queue that this would be attached to asynchronous?

BURSTMARK [1, ...]:
- How large is the burst size for burst valid?

CONFLICT_PROOF [0, 1]:
- Synchronous queue CONFLICT_PROOF setting

REGISTERED_IN [0, 1]:
- Synchronous queue REGISTERED_IN setting

REGISTERED_IN_BRAM [0, 1]:
- Synchronous queue REGISTERED_IN_BRAM setting

REGISTERED_OUT_BRAM [0, 1]:
- Both sync/async common REGISTERED_OUT_BRAM setting

*/
import constant_functions_pkg::*;

module queue_pop_coupler #(
    parameter DATA_WIDTH,
    parameter ADDR_WIDTH,
    parameter ASYNC,
    parameter BURSTMARK,
    // if not ASYNC, additional queue_sync parameters:
    parameter CONFLICT_PROOF,
    parameter REGISTERED_IN,
    parameter REGISTERED_IN_BRAM,

    // common to both sync/async
    parameter REGISTERED_OUT_BRAM,

    ////////////////////////////////////////////////////////////////
    // Globally Defined Locally Set Parameters
    localparam SPOOL_UP                       = queue_pop_coupler_SPOOL_UP(ASYNC, CONFLICT_PROOF, REGISTERED_IN, REGISTERED_IN_BRAM, REGISTERED_OUT_BRAM),
    localparam SPOOL_DOWN                     = queue_pop_coupler_SPOOL_DOWN(),
    localparam RESERVOIR_WATERMARK_ENTRIES    = queue_pop_coupler_RESERVOIR_WATERMARK_ENTRIES(SPOOL_UP, BURSTMARK),
    localparam RESERVOIR_BACKPRESSURE_ENTRIES = queue_pop_coupler_RESERVOIR_BACKPRESSURE_ENTRIES(SPOOL_UP, SPOOL_DOWN)
) (
    input rd_clk_i,
    input rd_rst_i,

    // fill side / queue side
    input                      empty_i,
    input                      lookahead_i,
    input [DATA_WIDTH - 1 : 0] rd_data_i,
    input                      rd_valid_i,

    output                  pop_o,
    output [ADDR_WIDTH : 0] less_than_or_eq_o,

    // drain side
    output [DATA_WIDTH - 1 : 0] rd_data_o,
    output                      rd_valid_o,
    output                      burstvalid_o,

    input ready_i // drivable with burstready
);

    // Fill side
    logic fill_ready_o;

    // control state
    logic queue_pop;
    logic queue_pop_next;

    always@(posedge rd_clk_i) begin
        queue_pop <= queue_pop_next;
    end

    assign pop_o = queue_pop;
    assign less_than_or_eq_o = 1;

    reservoir #(
        .DATA_WIDTH(DATA_WIDTH),
        .WATERMARK_ENTRIES(RESERVOIR_WATERMARK_ENTRIES),
        .BACKPRESSURE_ENTRIES(RESERVOIR_BACKPRESSURE_ENTRIES),
        .BURSTMARK(BURSTMARK)
    ) pop_coupler (
        .clk_i(rd_clk_i),
        .rst_i(rd_rst_i),

        .fill_data_i (rd_data_i),
        .fill_valid_i(rd_valid_i),
        .fill_ready_o(fill_ready_o),

        .drain_ready_i(ready_i),
        .drain_data_o(rd_data_o),
        .drain_valid_o(rd_valid_o),
        .drain_burstmark_o(burstvalid_o)
    );

    always_comb begin
        if((!empty_i) & (!lookahead_i))         // Not empty, more than one item left

            if(fill_ready_o) begin // reservoir ready
                queue_pop_next = 1;
            end else begin
                queue_pop_next = 0;
            end

        else if((!empty_i) & lookahead_i) begin // Not empty, but one item left

            if(fill_ready_o) begin // reservoir ready
                if(queue_pop) begin // already about to queue_pop
                    queue_pop_next = 0;
                end else begin
                    queue_pop_next = 1;
                end
            end else begin
                queue_pop_next = 0;
            end

        end else begin                         // Empty
            queue_pop_next = 0;
        end

        if(rd_rst_i) begin
            queue_pop_next = 0;
        end
    end

endmodule
