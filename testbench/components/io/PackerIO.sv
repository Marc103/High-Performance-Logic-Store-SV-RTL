import constant_functions_pkg::*;

class PackerIO #(
    parameter REGISTERED_IN,
    parameter DATA_WIDTH,
    parameter INGRESS_SIZE,
    parameter EGRESS_SIZE,

    ////////////////////////////////////////////////////////////////
    // Globally Defined Locally Set Parameters
    localparam STRIDE = packer_STRIDE(INGRESS_SIZE, EGRESS_SIZE),
    localparam LATENCY = packer_LATENCY(REGISTERED_IN, STRIDE)
);

    `PACKER_IO_IN_STRUCT(DATA_WIDTH, INGRESS_SIZE)
    `PACKER_IO_OUT_STRUCT(DATA_WIDTH, EGRESS_SIZE)

    packer_io_in_t packer_io_in_q[$];
    packer_io_out_t packer_io_out_q[$];

    // Sequencing Info
    bit idle[$];
    logic unsigned [7:0] error_state[$];
    logic end_last_sequence = 0;

    function new();
    endfunction
endclass
