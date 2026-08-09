`ifndef QUEUE_PUSH_COUPLER_INF
    `define QUEUE_PUSH_COUPLER_INF
interface queue_push_coupler_inf #(
    parameter DATA_WIDTH,
    parameter SIMPLE,
    parameter ASYNC,
    parameter BURST_SIZE,
    parameter ADDR_WIDTH,

    ////////////////////////////////////////////////////////////////
    // Globally Defined Locally Set Parameters
    localparam DATA_DEPTH = queue_DATA_DEPTH(ADDR_WIDTH)
) (
    input wr_clk_i
);
    logic wr_rst_i;

    logic [DATA_WIDTH - 1 : 0] wr_data_i;
    logic                      wr_valid_i;
    logic                      ready_o;
    logic                      burstready_o;

    logic full_i;
    logic lookahead_i;

    logic [DATA_WIDTH - 1 : 0] wr_data_o;
    logic                      push_o;
    logic [ADDR_WIDTH : 0]     more_than_or_eq_o;

    // testbench sequencing signals
    logic start_sequence;
    logic end_sequence;
    logic end_last_sequence;
    logic idle;
endinterface
`endif
