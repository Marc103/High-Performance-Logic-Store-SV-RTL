`ifndef PACKER_INF
    `define PACKER_INF
interface packer_inf #(
    parameter REGISTERED_IN,
    parameter DATA_WIDTH,
    parameter INGRESS_SIZE,
    parameter EGRESS_SIZE,

    ////////////////////////////////////////////////////////////////
    // Globally Defined Locally Set Parameters
    localparam STRIDE = packer_STRIDE(INGRESS_SIZE, EGRESS_SIZE),
    localparam LATENCY = packer_LATENCY(REGISTERED_IN, STRIDE)
) (
    input clk_i
);
    logic [INGRESS_SIZE - 1 : 0][DATA_WIDTH - 1 : 0] unpacked_i;
    logic                                               sync_i;

    logic [EGRESS_SIZE - 1 : 0][DATA_WIDTH - 1 : 0] packed_o;
    logic                                              packer_valid_o;

    // testbench sequencing signals
    logic start_sequence;
    logic end_sequence;
    logic end_last_sequence;
    logic idle;
endinterface
`endif
