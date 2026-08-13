/*
Queue Carriage.
Integrates queue_push_coupler -> queue/queue_async -> queue_pop_coupler.

When ASYNC is 0, wr_clk_i and rd_clk_i must be the same clock, and wr_rst_i
and rd_rst_i must represent the same reset. When ASYNC is 1, the clocks and
resets may be independent and the queue_async CDC constraints still apply.

Reset must be asserted for several clock cycles and followed by several idle
cycles before write or read traffic begins.

DATA_WIDTH:
- Sets the data width of the couplers and queue.

ADDR_WIDTH:
- Sets the address width and therefore the data depth of the queue.

ASYNC [0, 1]:
- If 1, instantiates queue_async between the couplers.
- If 0, instantiates queue between the couplers. The write and read clocks must
  be the same clock, and the write and read resets must represent the same reset.

PUSH_SIMPLE [0, 1]:
- Selects the queue_push_coupler simple or reservoir-backed implementation.
- If PUSH_SIMPLE is 1, ASYNC is 1, and PUSH_BURST_SIZE is greater than 1,
  burst admission is unsupported and wr_burstready_o remains 0. Normal
  single-item transfers using wr_ready_o remain available.

PUSH_BURST_SIZE [1, 2 ** ADDR_WIDTH]:
- Sets the queue_push_coupler burst-ready burst size.

POP_BURSTMARK [1, ...]:
- Sets the queue_pop_coupler burst-valid watermark.

CONFLICT_PROOF [0, 1]:
- Sets the synchronous queue conflict-proof behavior for simultaneous push and
  pop operations at the full or empty boundaries.
- Only applies when ASYNC is 0.

REGISTERED_IN [0, 1]:
- Selects direct or registered inputs for the synchronous queue.
- Only applies when ASYNC is 0.

REGISTERED_IN_BRAM [0, 1]:
- Selects direct or registered BRAM inputs for the synchronous queue.
- Only applies when ASYNC is 0.

REGISTERED_OUT_BRAM [0, 1]:
- Selects direct or registered BRAM output data for the selected queue.
- Applies to both synchronous and asynchronous queue implementations.

SYNC_STAGES [1, ...]:
- Sets the number of pointer synchronization stages in queue_async. Two or more
  stages should be used for clock-domain crossing.
- Only applies when ASYNC is 1.
*/

import constant_functions_pkg::*;

module queue_carriage #(
    parameter DATA_WIDTH,
    parameter ADDR_WIDTH,
    parameter ASYNC,

    parameter PUSH_SIMPLE,
    parameter PUSH_BURST_SIZE,
    parameter POP_BURSTMARK,

    parameter CONFLICT_PROOF,
    parameter REGISTERED_IN,
    parameter REGISTERED_IN_BRAM,
    parameter REGISTERED_OUT_BRAM,
    parameter SYNC_STAGES,

    ////////////////////////////////////////////////////////////////
    // Globally Defined Locally Set Parameters
    localparam QUEUE_READ_LATENCY = queue_carriage_READ_LATENCY(
        ASYNC,
        CONFLICT_PROOF,
        REGISTERED_IN,
        REGISTERED_IN_BRAM,
        REGISTERED_OUT_BRAM
    )
) (
    // Write side
    input wr_clk_i,
    input wr_rst_i,

    input  [DATA_WIDTH - 1 : 0] wr_data_i,
    input                       wr_valid_i,
    output                      wr_ready_o,
    output                      wr_burstready_o,

    // Read side
    input rd_clk_i,
    input rd_rst_i,

    output [DATA_WIDTH - 1 : 0] rd_data_o,
    output                      rd_valid_o,
    output                      rd_burstvalid_o,
    input                       rd_ready_i
);

    logic [DATA_WIDTH - 1 : 0] queue_wr_data;
    logic                      queue_push;
    logic                      queue_full;
    logic                      queue_write_lookahead;
    logic [ADDR_WIDTH : 0]     queue_more_than_or_eq;

    logic [DATA_WIDTH - 1 : 0] queue_rd_data;
    logic                      queue_rd_valid;
    logic                      queue_pop;
    logic                      queue_empty;
    logic                      queue_read_lookahead;
    logic [ADDR_WIDTH : 0]     queue_less_than_or_eq;

    queue_push_coupler #(
        .DATA_WIDTH(DATA_WIDTH),
        .SIMPLE(PUSH_SIMPLE),
        .ASYNC(ASYNC),
        .BURST_SIZE(PUSH_BURST_SIZE),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) push_coupler (
        .wr_clk_i(wr_clk_i),
        .wr_rst_i(wr_rst_i),

        .wr_data_i(wr_data_i),
        .wr_valid_i(wr_valid_i),
        .ready_o(wr_ready_o),
        .burstready_o(wr_burstready_o),

        .full_i(queue_full),
        .lookahead_i(queue_write_lookahead),

        .wr_data_o(queue_wr_data),
        .push_o(queue_push),
        .more_than_or_eq_o(queue_more_than_or_eq)
    );

    generate
        if(ASYNC == 1) begin : queue_async_g
            queue_async #(
                .ADDR_WIDTH(ADDR_WIDTH),
                .DATA_WIDTH(DATA_WIDTH),
                .REGISTERED_OUT_BRAM(REGISTERED_OUT_BRAM),
                .SYNC_STAGES(SYNC_STAGES)
            ) queue_inst (
                .wr_clk_i(wr_clk_i),
                .wr_rst_i(wr_rst_i),

                .push_i(queue_push),
                .wr_data_i(queue_wr_data),
                .full_o(queue_full),
                .one_space_left_o(queue_write_lookahead),

                .rd_clk_i(rd_clk_i),
                .rd_rst_i(rd_rst_i),

                .pop_i(queue_pop),
                .rd_data_o(queue_rd_data),
                .empty_o(queue_empty),
                .one_item_left_o(queue_read_lookahead)
            );
        end else begin : queue_sync_g
            queue #(
                .ADDR_WIDTH(ADDR_WIDTH),
                .DATA_WIDTH(DATA_WIDTH),
                .CONFLICT_PROOF(CONFLICT_PROOF),
                .REGISTERED_IN(REGISTERED_IN),
                .REGISTERED_IN_BRAM(REGISTERED_IN_BRAM),
                .REGISTERED_OUT_BRAM(REGISTERED_OUT_BRAM)
            ) queue_inst (
                .clk_i(wr_clk_i),
                .rst_i(wr_rst_i),

                .push_i(queue_push),
                .wr_data_i(queue_wr_data),

                .pop_i(queue_pop),
                .rd_data_o(queue_rd_data),

                .full_o(queue_full),
                .empty_o(queue_empty),

                .less_than_i(queue_less_than_or_eq),
                .less_than_o(queue_read_lookahead),

                .more_than_i(queue_more_than_or_eq),
                .more_than_o(queue_write_lookahead)
            );
        end
    endgenerate

    logic [QUEUE_READ_LATENCY - 1 : 0] queue_rd_valid_pipeline;
    always@(posedge rd_clk_i) begin
        if(rd_rst_i) begin
            queue_rd_valid_pipeline <= '0;
        end else begin
            queue_rd_valid_pipeline[0] <= queue_pop;
            for(int stage = 1; stage < QUEUE_READ_LATENCY; stage++) begin
                queue_rd_valid_pipeline[stage] <= queue_rd_valid_pipeline[stage - 1];
            end
        end
    end

    assign queue_rd_valid = queue_rd_valid_pipeline[QUEUE_READ_LATENCY - 1];

    queue_pop_coupler #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .ASYNC(ASYNC),
        .BURSTMARK(POP_BURSTMARK),
        .CONFLICT_PROOF(CONFLICT_PROOF),
        .REGISTERED_IN(REGISTERED_IN),
        .REGISTERED_IN_BRAM(REGISTERED_IN_BRAM),
        .REGISTERED_OUT_BRAM(REGISTERED_OUT_BRAM)
    ) pop_coupler (
        .rd_clk_i(rd_clk_i),
        .rd_rst_i(rd_rst_i),

        .empty_i(queue_empty),
        .lookahead_i(queue_read_lookahead),
        .rd_data_i(queue_rd_data),
        .rd_valid_i(queue_rd_valid),

        .pop_o(queue_pop),
        .less_than_or_eq_o(queue_less_than_or_eq),

        .rd_data_o(rd_data_o),
        .rd_valid_o(rd_valid_o),
        .burstvalid_o(rd_burstvalid_o),

        .ready_i(rd_ready_i)
    );

endmodule
