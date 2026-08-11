`ifndef QUEUE_CARRIAGE_INF
    `define QUEUE_CARRIAGE_INF

interface queue_carriage_inf #(
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
    parameter SYNC_STAGES
) (
    input wr_clk_i,
    input rd_clk_i
);
    logic wr_rst_i;
    logic rd_rst_i;

    logic [DATA_WIDTH - 1 : 0] wr_data_i;
    logic                      wr_valid_i;
    logic                      wr_ready_o;
    logic                      wr_burstready_o;

    logic [DATA_WIDTH - 1 : 0] rd_data_o;
    logic                      rd_valid_o;
    logic                      rd_burstvalid_o;
    logic                      rd_ready_i;

    // testbench sequencing signals
    logic start_sequence;
    logic end_sequence;
    logic end_last_sequence;
    logic idle;
endinterface

`endif
