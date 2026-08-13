/*
Queue Train.
Connects one or more queue_carriage instances in a ready/valid chain.

The train has a write clock domain and a read clock domain. FRONT_ASYNC places
the crossing in the first carriage; all following carriages use the read
domain. END_ASYNC places the crossing in the last carriage; all preceding
carriages use the write domain. When either option is enabled, the write and
read domains are assumed distinct and the queue_async CDC constraints apply.

For NUMBER_OF_CARRIAGES greater than 1, FRONT_ASYNC and END_ASYNC cannot both
be 1 because only two clock domains are provided and the train can contain
only one transition between them. If both options are 0, the user must drive
wr_clk_i/rd_clk_i with the same clock and wr_rst_i/rd_rst_i with the same reset.

When NUMBER_OF_CARRIAGES is 1, the sole carriage is both the front and end.
It is asynchronous when either FRONT_ASYNC or END_ASYNC is 1 and directly
crosses from wr_clk_i/wr_rst_i to rd_clk_i/rd_rst_i. In this asynchronous
case, the write and read domains are assumed distinct.
If both async parameters are 0, the write and read clocks/resets must match.

Reset must be asserted for several cycles in every active clock domain and
followed by several idle cycles before traffic begins.

DATA_WIDTH:
- Sets the data width of every queue_carriage.

ADDR_WIDTH:
- Sets the address width and therefore the data depth of every queue_carriage.

NUMBER_OF_CARRIAGES [1, ...]:
- Sets the number of queue_carriage instances connected in series.

FRONT_ASYNC [0, 1]:
- If 1, the front carriage crosses from the write clock domain into the
  read clock domain. Every following carriage uses the read domain.

END_ASYNC [0, 1]:
- If 1, the end carriage crosses from the write clock domain into the read
  clock domain. Every preceding carriage uses the write domain.

PUSH_SIMPLE [0, 1]:
- Selects the simple or reservoir-backed push coupler implementation for all
  carriages.
- If PUSH_SIMPLE is 1, PUSH_BURST_SIZE is greater than 1, and the front
  carriage is asynchronous, burst admission is unsupported and
  wr_burstready_o remains 0. The front carriage is asynchronous when
  FRONT_ASYNC is 1, or for a one-carriage train when END_ASYNC is 1.
  Normal single-item transfers using wr_ready_o remain available.

PUSH_BURST_SIZE [1, 2 ** ADDR_WIDTH]:
- Sets the burst-ready burst size of the front carriage.
- Internal carriage links use a burst size of 1.

POP_BURSTMARK [1, ...]:
- Sets the burst-valid watermark of the end carriage.
- Internal carriage links use a burst mark of 1.

CONFLICT_PROOF [0, 1]:
- Sets the conflict-proof behavior of every synchronous carriage queue.

REGISTERED_IN [0, 1]:
- Selects direct or registered inputs for every synchronous carriage queue.

REGISTERED_IN_BRAM [0, 1]:
- Selects direct or registered BRAM inputs for every synchronous carriage.

REGISTERED_OUT_BRAM [0, 1]:
- Selects direct or registered BRAM outputs for every carriage.

SYNC_STAGES [1, ...]:
- Sets the pointer synchronization stages of each asynchronous carriage.
  Two or more stages should be used for clock-domain crossing.
*/

module queue_train #(
    parameter DATA_WIDTH,
    parameter ADDR_WIDTH,
    parameter NUMBER_OF_CARRIAGES,

    parameter FRONT_ASYNC,
    parameter END_ASYNC,

    parameter PUSH_SIMPLE,
    parameter PUSH_BURST_SIZE,
    parameter POP_BURSTMARK,

    parameter CONFLICT_PROOF,
    parameter REGISTERED_IN,
    parameter REGISTERED_IN_BRAM,
    parameter REGISTERED_OUT_BRAM,
    parameter SYNC_STAGES
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

    logic [NUMBER_OF_CARRIAGES : 0][DATA_WIDTH - 1 : 0] carriage_data;
    logic [NUMBER_OF_CARRIAGES : 0]                    carriage_valid;
    logic [NUMBER_OF_CARRIAGES : 0]                    carriage_ready;

    logic [NUMBER_OF_CARRIAGES - 1 : 0] carriage_burstready;
    logic [NUMBER_OF_CARRIAGES - 1 : 0] carriage_burstvalid;

    assign carriage_data[0]  = wr_data_i;
    assign carriage_valid[0] = wr_valid_i;
    assign wr_ready_o         = carriage_ready[0];
    assign wr_burstready_o    = carriage_burstready[0];

    assign rd_data_o                           = carriage_data[NUMBER_OF_CARRIAGES];
    assign rd_valid_o                          = carriage_valid[NUMBER_OF_CARRIAGES];
    assign rd_burstvalid_o                     = carriage_burstvalid[NUMBER_OF_CARRIAGES - 1];
    assign carriage_ready[NUMBER_OF_CARRIAGES] = rd_ready_i;

    generate
        for(genvar carriage = 0; carriage < NUMBER_OF_CARRIAGES; carriage++) begin : carriage_g
            localparam CARRIAGE_ASYNC = (
                ((carriage == 0) && (FRONT_ASYNC == 1)) ||
                ((carriage == (NUMBER_OF_CARRIAGES - 1)) && (END_ASYNC == 1))
            ) ? 1 : 0;

            localparam CARRIAGE_PUSH_BURST_SIZE =
                (carriage == 0) ? PUSH_BURST_SIZE : 1;

            localparam CARRIAGE_POP_BURSTMARK =
                (carriage == (NUMBER_OF_CARRIAGES - 1)) ? POP_BURSTMARK : 1;

            queue_carriage #(
                .DATA_WIDTH(DATA_WIDTH),
                .ADDR_WIDTH(ADDR_WIDTH),
                .ASYNC(CARRIAGE_ASYNC),
                .PUSH_SIMPLE(PUSH_SIMPLE),
                .PUSH_BURST_SIZE(CARRIAGE_PUSH_BURST_SIZE),
                .POP_BURSTMARK(CARRIAGE_POP_BURSTMARK),
                .CONFLICT_PROOF(CONFLICT_PROOF),
                .REGISTERED_IN(REGISTERED_IN),
                .REGISTERED_IN_BRAM(REGISTERED_IN_BRAM),
                .REGISTERED_OUT_BRAM(REGISTERED_OUT_BRAM),
                .SYNC_STAGES(SYNC_STAGES)
            ) carriage_inst (
                .wr_clk_i(
                    ((carriage == 0) || (FRONT_ASYNC == 0))
                        ? wr_clk_i
                        : rd_clk_i
                ),
                .wr_rst_i(
                    ((carriage == 0) || (FRONT_ASYNC == 0))
                        ? wr_rst_i
                        : rd_rst_i
                ),
                .wr_data_i(carriage_data[carriage]),
                .wr_valid_i(carriage_valid[carriage]),
                .wr_ready_o(carriage_ready[carriage]),
                .wr_burstready_o(carriage_burstready[carriage]),

                .rd_clk_i(
                    ((carriage == (NUMBER_OF_CARRIAGES - 1)) || (FRONT_ASYNC == 1))
                        ? rd_clk_i
                        : wr_clk_i
                ),
                .rd_rst_i(
                    ((carriage == (NUMBER_OF_CARRIAGES - 1)) || (FRONT_ASYNC == 1))
                        ? rd_rst_i
                        : wr_rst_i
                ),
                .rd_data_o(carriage_data[carriage + 1]),
                .rd_valid_o(carriage_valid[carriage + 1]),
                .rd_burstvalid_o(carriage_burstvalid[carriage]),
                .rd_ready_i(carriage_ready[carriage + 1])
            );
        end
    endgenerate

endmodule
