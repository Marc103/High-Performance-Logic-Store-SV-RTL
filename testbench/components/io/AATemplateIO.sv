import constant_functions_pkg::*;

class ???IO #(
    ???

    ////////////////////////////////////////////////////////////////
    // Globally Defined Locally Set Parameters

    ???
);

    `???_IO_IN_STRUCT(???)
    `???_IO_OUT_STRUCT(???)

    ???

    ???_io_in_t ???_io_in_q[$];
    ???_io_out_t ???_io_out_q[$];

    // Sequencing Info
    bit idle [$];
    logic unsigned [7:0] error_state[$];
    logic end_last_sequence = 0;

    function new ();
    endfunction

endclass