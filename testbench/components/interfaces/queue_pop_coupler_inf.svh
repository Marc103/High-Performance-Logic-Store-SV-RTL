`ifndef QUEUE_POP_COUPLER_INF
    `define QUEUE_POP_COUPLER_INF
interface queue_pop_coupler_inf #(
    parameter DATA_WIDTH,
    parameter ADDR_WIDTH,
    parameter ASYNC,
    parameter BURSTMARK,
    parameter CONFLICT_PROOF,
    parameter REGISTERED_IN,
    parameter REGISTERED_IN_BRAM,
    parameter REGISTERED_OUT_BRAM
) (
    input rd_clk_i
);
    logic rd_rst_i;

    logic                      empty_i;
    logic                      lookahead_i;
    logic [DATA_WIDTH - 1 : 0] rd_data_i;
    logic                      rd_valid_i;

    logic                  pop_o;
    logic [ADDR_WIDTH : 0] less_than_or_eq_o;

    logic [DATA_WIDTH - 1 : 0] rd_data_o;
    logic                      rd_valid_o;
    logic                      burstvalid_o;
    logic                      ready_i;

    logic start_sequence;
    logic end_sequence;
    logic end_last_sequence;
    logic idle;
endinterface
`endif
