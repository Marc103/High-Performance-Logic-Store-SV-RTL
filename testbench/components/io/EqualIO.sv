import constant_functions_pkg::*;

class EqualIO #(
    parameter DATA_WIDTH,
    parameter REGISTERED_IN,
    parameter GRADE,

    ////////////////////////////////////////////////////////////////
    // Globally Defined Locally Set Parameters
    localparam LATENCY = equal_LATENCY(REGISTERED_IN, GRADE)
);

    `EQUAL_IO_IN_STRUCT(DATA_WIDTH)
    `EQUAL_IO_OUT_STRUCT

    equal_io_in_t equal_io_in_q[$];
    equal_io_out_t equal_io_out_q[$];

    // Sequencing Info
    bit idle [$];
    logic unsigned [7:0] error_state[$];
    logic end_last_sequence = 0;

    function new ();
    endfunction

endclass
