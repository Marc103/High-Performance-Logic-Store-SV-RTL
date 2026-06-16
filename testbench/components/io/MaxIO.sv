import constant_functions_pkg::*;

class MaxIO #(
    parameter DATA_WIDTH,
    parameter SIGNED,
    parameter REGISTERED_IN,
    parameter GRADE,

    ////////////////////////////////////////////////////////////////
    // Globally Defined Locally Set Parameters
    localparam LATENCY = max_LATENCY(REGISTERED_IN, GRADE)
);

    `MAX_IO_IN_STRUCT(DATA_WIDTH)
    `MAX_IO_OUT_STRUCT(DATA_WIDTH)

    max_io_in_t max_io_in_q[$];
    max_io_out_t max_io_out_q[$];

    // Sequencing Info
    bit idle [$];
    logic unsigned [7:0] error_state[$];
    logic end_last_sequence = 0;

    function new ();
    endfunction

endclass
