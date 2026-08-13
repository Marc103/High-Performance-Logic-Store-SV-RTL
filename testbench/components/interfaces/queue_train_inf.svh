`ifndef QUEUE_TRAIN_INF
    `define QUEUE_TRAIN_INF

interface queue_train_inf #(
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
