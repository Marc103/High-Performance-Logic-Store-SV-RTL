import constant_functions_pkg::*;

class FftAcceleratorIO #(
    parameter BASE = 16,
    parameter EXPONENT_WIDTH = 6,
    parameter MANTISSA_WIDTH = 25,
    parameter SAMPLES_ADDR_WIDTH = 15,
    parameter TWIDDLES_ADDR_WIDTH = 14,
    parameter READ_LATENCY = 1,
    parameter WRITE_LATENCY = 1,
    parameter RESET_PIPELINE_DEPTH = 1,
    parameter LUTX = 6,
    parameter GRADE = 1,
    parameter REGSITERED_MULTIPLIER = 1,
    parameter REGISTERED_NORMALIZE = 1,
    parameter REGISTERED_SWAP_IN = 1,
    parameter REGISTERED_SWAP_MUX = 1,
    parameter REGISTERED_ALIGN_STICKY_IN = 1,
    parameter REGISTERED_ALIGN_EXPONENT_MUX = 1,
    parameter REGISTERED_ALIGN_MUX = 1,
    parameter REGISTERED_ADD_CONVERT = 1,
    parameter REGISTERED_ADD_CONVERT_CONVERT = 1,
    parameter REGISTERED_PRIORITY_ENCODE = 1,
    parameter REGISTERED_PRIORITY_ENCODE_ENCODER = 1,
    parameter REGISTERED_NORMALIZE_ROUND_POST_NORMALIZE = 1,
    parameter REGISTERED_NORMALIZE_ROUND_POST_NORMALIZE_ROUND = 1,
    parameter II_CYCLES = 4,
    parameter real CLOCK_PERIOD_NS = 10.0,
    parameter GATE_LEVEL_SIM = 0,
    parameter PORT_SAMPLE_AT_POSEDGE = GATE_LEVEL_SIM,
    parameter FFT_POINTS = 32768,
    parameter FFT_COUNT = 1,
    parameter string SAMPLES_FILE = "6_25_samples_0.txt",
    parameter string TWIDDLES_FILE = "6_25_twiddles_0.txt",
    parameter string RESULT_FILE = "6_25_result_0.txt"
,
    localparam DATA_WIDTH = fft_multiplier_core_DATA_WIDTH(EXPONENT_WIDTH, MANTISSA_WIDTH),
    localparam COMPLEX_DATA_WIDTH = fft_accelerator_COMPLEX_DATA_WIDTH(EXPONENT_WIDTH, MANTISSA_WIDTH),
    localparam LATENCY = fft_accelerator_LATENCY(
        BASE,
        MANTISSA_WIDTH,
        LUTX,
        GRADE,
        REGSITERED_MULTIPLIER,
        REGISTERED_NORMALIZE,
        REGISTERED_SWAP_IN,
        REGISTERED_SWAP_MUX,
        REGISTERED_ALIGN_STICKY_IN,
        REGISTERED_ALIGN_EXPONENT_MUX,
        REGISTERED_ALIGN_MUX,
        REGISTERED_ADD_CONVERT,
        REGISTERED_ADD_CONVERT_CONVERT,
        REGISTERED_PRIORITY_ENCODE,
        REGISTERED_PRIORITY_ENCODE_ENCODER,
        REGISTERED_NORMALIZE_ROUND_POST_NORMALIZE,
        REGISTERED_NORMALIZE_ROUND_POST_NORMALIZE_ROUND,
        READ_LATENCY
    ),
    localparam WRITE_COMMIT_LATENCY = fft_accelerator_WRITE_COMMIT_LATENCY(
        BASE,
        MANTISSA_WIDTH,
        LUTX,
        GRADE,
        REGSITERED_MULTIPLIER,
        REGISTERED_NORMALIZE,
        REGISTERED_SWAP_IN,
        REGISTERED_SWAP_MUX,
        REGISTERED_ALIGN_STICKY_IN,
        REGISTERED_ALIGN_EXPONENT_MUX,
        REGISTERED_ALIGN_MUX,
        REGISTERED_ADD_CONVERT,
        REGISTERED_ADD_CONVERT_CONVERT,
        REGISTERED_PRIORITY_ENCODE,
        REGISTERED_PRIORITY_ENCODE_ENCODER,
        REGISTERED_NORMALIZE_ROUND_POST_NORMALIZE,
        REGISTERED_NORMALIZE_ROUND_POST_NORMALIZE_ROUND,
        READ_LATENCY,
        WRITE_LATENCY
    ),
    localparam RESET_HOLD_CYCLES = fft_accelerator_RESET_HOLD_CYCLES(RESET_PIPELINE_DEPTH, WRITE_LATENCY),
    localparam SAMPLE_CAPACITY = 32768,
    localparam TWIDDLE_CAPACITY = 16384
);
    `FFT_ACCELERATOR_IO_IN_STRUCT(SAMPLES_ADDR_WIDTH)
    `FFT_ACCELERATOR_IO_OUT_STRUCT
    typedef logic [DATA_WIDTH - 1 : 0] word_t;
    typedef logic [COMPLEX_DATA_WIDTH - 1 : 0] complex_t;
    typedef struct packed {
        longint unsigned cycle;
        logic [SAMPLES_ADDR_WIDTH - 1 : 0] address;
        complex_t data;
    } write_event_t;
    typedef struct packed {
        longint unsigned cycle;
        logic [SAMPLES_ADDR_WIDTH - 1 : 0] address;
        logic [TWIDDLES_ADDR_WIDTH - 1 : 0] twiddle_address;
        bit is_b;
    } read_event_t;

    typedef AlternateBaseFpAdderIO #(
        .BASE(BASE),
        .EXPONENT_WIDTH(EXPONENT_WIDTH),
        .MANTISSA_WIDTH(MANTISSA_WIDTH),
        .LUTX(LUTX),
        .GRADE(GRADE),
        .REGISTERED_SWAP_IN(REGISTERED_SWAP_IN),
        .REGISTERED_SWAP_MUX(REGISTERED_SWAP_MUX),
        .REGISTERED_ALIGN_STICKY_IN(REGISTERED_ALIGN_STICKY_IN),
        .REGISTERED_ALIGN_EXPONENT_MUX(REGISTERED_ALIGN_EXPONENT_MUX),
        .REGISTERED_ALIGN_MUX(REGISTERED_ALIGN_MUX),
        .REGISTERED_ADD_CONVERT(REGISTERED_ADD_CONVERT),
        .REGISTERED_ADD_CONVERT_CONVERT(REGISTERED_ADD_CONVERT_CONVERT),
        .REGISTERED_PRIORITY_ENCODE(REGISTERED_PRIORITY_ENCODE),
        .REGISTERED_PRIORITY_ENCODE_ENCODER(REGISTERED_PRIORITY_ENCODE_ENCODER),
        .REGISTERED_NORMALIZE_ROUND_POST_NORMALIZE(REGISTERED_NORMALIZE_ROUND_POST_NORMALIZE),
        .REGISTERED_NORMALIZE_ROUND_POST_NORMALIZE_ROUND(REGISTERED_NORMALIZE_ROUND_POST_NORMALIZE_ROUND)
    ) adder_io_t;
    typedef AlternateBaseFpMultiplierIO #(
        .BASE(BASE), .EXPONENT_WIDTH(EXPONENT_WIDTH), .MANTISSA_WIDTH(MANTISSA_WIDTH),
        .LUTX(LUTX), .GRADE(GRADE), .REGISTERED_IN(REGSITERED_MULTIPLIER), .REGISTERED_NORMALIZE(REGISTERED_NORMALIZE)
    ) multiplier_io_t;
    fft_accelerator_io_in_t fft_accelerator_io_in_q[$];
    fft_accelerator_io_out_t fft_accelerator_io_out_q[$];
    complex_t initial_samples[], twiddles[], final_samples[];
    complex_t loaded_samples[], loaded_twiddles[];
    read_event_t reads[$];
    write_event_t writes[$], commits[$];
    bit idle[$];
    logic [7:0] error_state[$];
    bit end_last_sequence = 0;
    int points, count, sample_order_points = 32768, twiddle_points = 32768;
    real sample_rate_hz = 360.0;
    string samples_file, twiddles_file, result_file;
    longint unsigned elapsed_cycles;
    function new(); endfunction

    static function automatic int reverse_bits(int value, int bits);
        int result;
        result=0;
        repeat(bits) begin result=(result<<1)|(value&1); value=value>>1; end
        return result;
    endfunction
    static function automatic bit is_power_of_two(int value);
        return value>0 && (value&(value-1))==0;
    endfunction
    static function automatic string normalize_path(string value);
        for(int i=0;i<value.len();i++) if(value[i]==8'h5c) value[i]=8'h2f;
        return value;
    endfunction
    static function automatic string resolve_path(string directory, string value);
        value=normalize_path(value);
        for(int i=0;i<value.len();i++) if(value[i]==8'h2f || value[i]==8'h3a) return value;
        return {normalize_path(directory), "/", value};
    endfunction
endclass
