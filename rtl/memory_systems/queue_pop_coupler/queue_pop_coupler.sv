/*
Queue Pop Coupler.
Exposes valid/burstvalid/ready interface on the push side (write side)
of a queue. Designed to work with 'queue' or 'queue_async'.
*/
import constant_functions_pkg::*;

module queue_pop_coupler #(
    parameter DATA_WIDTH,
    parameter ADDR_WIDTH,
    parameter ASYNC,
    // if not ASYNC, additional queue_sync parameters:
    parameter CONFLICT_PROOF,
    parameter REGISTERED_IN,
    parameter REGISTERED_IN_BRAM,
    parameter REGISTERED_OUT_BRAM,
    parameter BURSTMARK,

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

    output                  pop_o,
    output [ADDR_WIDTH : 0] less_than_or_eq_o,

    // drain side
    output [DATA_WIDTH - 1 : 0] rd_data_o,
    output                      valid_o,
    output                      burstvalid_o
    
);

    reservoir #(
        .DATA_WIDTH(DATA_WIDTH),
        .WATERMARK_ENTRIES(RESERVOIR_WATERMARK_ENTRIES),
        .BACKPRESSURE_ENTRIES(RESERVOIR_BACKPRESSURE_ENTRIES),
        .BURSTMARK(BURST_SIZE)
    )

endmodule