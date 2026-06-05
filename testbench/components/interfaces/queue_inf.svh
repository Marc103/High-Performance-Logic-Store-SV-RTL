`ifndef QUEUE_INF 
    `define QUEUE_INF
interface queue_inf #(
    parameter ADDR_WIDTH,
    parameter DATA_WIDTH,
    parameter CONFLICT_PROOF,       // [0, 1]
    parameter REGISTERED_IN,        // [0, 1]
    parameter REGISTERED_IN_BRAM,   // [0, 1]
    parameter REGISTERED_OUT_BRAM,  // [0, 1]
    parameter NUMBER_OF_QUEUES,     // [1,..]

    ////////////////////////////////////////////////////////////////
    // Globally Defined Locally Set Parameters
    localparam DATA_DEPTH        = queue_DATA_DEPTH                  (ADDR_WIDTH),
    localparam READ_LATENCY      = queue_READ_LATENCY                (CONFLICT_PROOF, REGISTERED_IN, REGISTERED_IN_BRAM, REGISTERED_OUT_BRAM),
    localparam WRITE_LATENCY     = queue_WRITE_LATENCY               (CONFLICT_PROOF, REGISTERED_IN, REGISTERED_IN_BRAM),
    localparam READ_LATENCY_BRAM = bram_dual_port_simple_READ_LATENCY(REGISTERED_IN_BRAM, REGISTERED_OUT_BRAM)
) (
    input clk_i
);
    logic                                                 rst_i;
    
    // write port
    logic                                                 push_i;
    logic  [NUMBER_OF_QUEUES - 1 : 0][DATA_WIDTH - 1 : 0] wr_data_i;

    // read port
    logic                                                pop_i;
    logic [NUMBER_OF_QUEUES - 1 : 0][DATA_WIDTH - 1 : 0] rd_data_o;

    // conditions
    logic                      full_o;
    logic                      empty_o;

    logic  [ADDR_WIDTH : 0]    less_than_i; 
    logic                      less_than_o; // less than 'less_than_i' elements on queue

    logic  [ADDR_WIDTH : 0]    more_than_i;
    logic                      more_than_o; // more than 'more_than_i' elements on the queue

    // testbench sequencing signals
    logic start_sequence;
    logic end_sequence;
    logic end_last_sequence;
    logic idle;
endinterface
`endif 