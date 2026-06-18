import constant_functions_pkg::*;

class PriorityEncoderIO #(
    parameter INPUT_DATA_WIDTH,
    parameter REGISTERED_IN,
    parameter LUTX,
    parameter GRADE,

    ////////////////////////////////////////////////////////////////
    // Globally Defined Locally Set Parameters
    localparam ENCODE_GROUPS     = priority_encoder_ENCODE_GROUPS    (INPUT_DATA_WIDTH, LUTX),
    localparam ENCODE_DEPTH      = priority_encoder_ENCODE_DEPTH     (ENCODE_GROUPS),
    localparam OUTPUT_DATA_WIDTH = priority_encoder_OUTPUT_DATA_WIDTH(INPUT_DATA_WIDTH),
    localparam LATENCY           = priority_encoder_LATENCY          (
        REGISTERED_IN,
        ENCODE_DEPTH,
        max_LATENCY(1, GRADE),
        max_LATENCY(0, GRADE)
    )
);

    `PRIORITY_ENCODER_IO_IN_STRUCT(INPUT_DATA_WIDTH)
    `PRIORITY_ENCODER_IO_OUT_STRUCT(OUTPUT_DATA_WIDTH)

    priority_encoder_io_in_t priority_encoder_io_in_q[$];
    priority_encoder_io_out_t priority_encoder_io_out_q[$];

    // Sequencing Info
    bit idle [$];
    logic unsigned [7:0] error_state[$];
    logic end_last_sequence = 0;

    function new ();
    endfunction

endclass
