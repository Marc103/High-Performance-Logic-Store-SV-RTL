`ifndef RESERVOIR_NO_BACKPRESSURE_INF
    `define RESERVOIR_NO_BACKPRESSURE_INF
interface reservoir_no_backpressure_inf #(
    parameter DATA_WIDTH,
    parameter WATERMARK_ENTRIES,
    parameter FILLMARK,
    parameter BURSTMARK,

    ////////////////////////////////////////////////////////////////
    // Globally Defined Locally Set Parameters
    localparam ENTRIES = reservoir_ENTRIES(WATERMARK_ENTRIES, 0)
) (
    input clk_i
);
    logic rst_i;

    logic [DATA_WIDTH - 1 : 0] fill_data_i;
    logic                      fill_valid_i;
    logic                      fill_ready_o;
    logic                      fill_burstready_o;

    logic                      drain_ready_i;
    logic [DATA_WIDTH - 1 : 0] drain_data_o;
    logic                      drain_valid_o;
    logic                      drain_burstmark_o;

    // testbench sequencing signals
    logic start_sequence;
    logic end_sequence;
    logic end_last_sequence;
    logic idle;
endinterface
`endif
