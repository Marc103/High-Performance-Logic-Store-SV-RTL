/* 
Queue (aka FIFO). ADDR_WIDTH X DATA_WIDTH of instantiated memory is determine 
by should fit within a single bram for best performance. Without READ_THEN_WRITE
enabled, simultaneous push/pop when there is one element left on the queue
behavior is undefined. Behavior of pushing to a full queue or popping from an
empty one is considered as undefined.

ADDR_WIDTH:
- Sets the address width, also determines the data depth of the BRAM.

DATA_WIDTH:
- Data width.

REGISTERED_IN [0, 1]:
- If 1, inputs are registered, increasing latency by 1 cycle,
  else, inputs are direct.

REGISTERED_IN_BRAM [0,1]:
- If 1, inputs of internal bram are first registered, increasing the latency by 1 cycle,
  else, inputs are direct.

READ_THEN_WRITE [0,1]:
- If 1, read happens first then write on a separate cycle, allowing for simultaneous push/pop
  whene there is one element left in the queue, at the cost of additional cycle of latency.

DISABLE_LTS_LEFT [0, 1]:
- If 1, lts_left_o is always driven low, meaning we don't compare lts_left_i to how much space
  is left on the queue to determine lts_left_o. 

DISABLE_ATL_LEFT [0, 1]:
- If 1, atl_left_o is always driven low, meaning we don't compare atl_left_i to how much elements
  are on the queue to determine lts_left_o. 
*/

import constant_functions_pkg::*; 

module queue #(
    parameter ADDR_WIDTH,
    parameter DATA_WIDTH,
    parameter REGISTERED_IN,        // [0, 1]
    parameter REGISTERED_IN_BRAM,   // [0, 1]
    parameter READ_THEN_WRITE,      // [0, 1]
    parameter DISABLE_LTS_LEFT,     // [0, 1]
    parameter DISABLE_ATL_LEFT,     // [0, 1]

    ////////////////////////////////////////////////////////////////
    // Globally Defined Locally Set Parameters
    localparam DATA_DEPTH = queue_DATA_DEPTH(ADDR_WIDTH),
    localparam LATENCY    = queue_LATENCY   (REGISTERED_IN, REGISTERED_IN_BRAM, READ_THEN_WRITE)
) (
    input clk_i,
    input rst_i,

    // write port
    input                       push_i,
    input  [DATA_WIDTH - 1 : 0] wr_data_i,
    output                      full_o,
    input  [ADDR_WIDTH - 1 : 0] lts_left_i, 
    output                      lts_left_o, // less than 'x' space left on queue

    // read port
    input                       pop_i,
    output [DATA_WIDTH - 1 : 0] rd_data_o,
    output                      empty_o,
    input  [ADDR_WIDTH - 1 : 0] atl_left_i,
    output                      atl_left_o // at least 'x' elements left on the queue
);

    // read/write port setting for REGISTERED_IN
    logic                      rst;

    logic                      push;
    logic [DATA_WIDTH - 1 : 0] wr_data;
    logic [ADDR_WIDTH - 1 : 0] lts_left;

    logic                      pop;
    logic [ADDR_WIDTH - 1 : 0] atl_left;


    always@(posedge clk_0_i) begin
        rst      <= rst_i;

        push     <= push_i;
        wr_data  <= wr_data_i;
        lts_left <= lts_left_i;

        pop      <= pop_i;
        atl_left <= atl_left_i;
    end

    logic                      rst_g;

    logic                      push_g;
    logic [DATA_WIDTH - 1 : 0] wr_data_g;
    logic [ADDR_WIDTH - 1 : 0] lts_left_g;

    logic                      pop_g;
    logic [ADDR_WIDTH - 1 : 0] atl_left_g;

    generate
        if(REGISTERED_IN == 1) begin
            assign rst_g     = rst;

            assign push_g     = push;
            assign wr_data_g  = wr_data;
            assign lts_left_g = lts_left;

            assign pop_g      = pop;
            assign atl_left_g = atl_left;
        end else begin
            assign rst_g     = rst_i;

            assign push_g     = push_i;
            assign wr_data_g  = wr_data_i;
            assign lts_left_g = lts_left_i;

            assign pop_g      = pop_i;
            assign atl_left_g = atl_left_i;
        end
    endgenerate


    // write state
    logic                      en_0;
    logic                      wr_en,
    logic [ADDR_WIDTH - 1 : 0] wr_addr;
    logic [DATA_WIDTH - 1 : 0] wr_data;

    logic [ADDR_WIDTH - 1 : 0] wr_addr_next;

    logic                      en_0_delay;
    logic                      wr_en_delay,
    logic [ADDR_WIDTH - 1 : 0] wr_addr_delay;
    logic [DATA_WIDTH - 1 : 0] wr_data_delay;

    // read state
    logic                      en_1;
    logic [ADDR_WIDTH - 1 : 0] rd_addr;
    logic [DATA_WIDTH - 1 : 0] rd_data;

    logic [ADDR_WIDTH - 1 : 0] rd_addr_next;

    logic [DATA_WIDTH - 1 : 0] rd_data_delay;

    // control state
    logic [ADDR_WIDTH : 0] element_count;
    logic [ADDR_WIDTH : 0] element_count_next;

    logic [ADDR_WIDTH : 0] space_left;

    always@(posedge clk_i) begin
        // write update
        wr_addr       <= wr_addr_next;

        en_0_delay    <= en_0;
        wr_en_delay   <= wr_en;
        wr_addr_delay <= wr_addr;
        wr_data_delay <= wr_data;

        // read update
        rd_addr       <= rd_addr_next;

        rd_data       <= rd_data_delay;

        // control state update
        element_count <= element_count_next;
    end

    always_comb begin
        // push (write) logic
        en_0  = push_g;
        wr_en = push_g;
        if(push_g) begin
            wr_addr_next = wr_addr + 1;
        end else begin
            wr_addr_next = wr_addr;
        end

        wr_data = wr_data_g;

        // pop (read) logic
        en_1 = pop_g;
        if(pop_g) begin
            rd_addr_next = rd_addr + 1;
        end else begin
            rd_addr_next = rd_addr;
        end
        
        // control state
        space_left = DATA_DEPTH - element_count;

        if          ((!push_g) & ( pop_g)) begin // no push, pop
            element_count_next = element_count - 1;
        end else if (( push_g) & (!pop_g)) begin // push, no pop
            element_count_next = element_count + 1;
        end else begin                           // push, pop or no push, no pop
            element_count_next = element_count;
        end

        if(rst_g) begin
            wr_addr_next = 0;
            rd_addr_next = 0;
        end
    end

    assign full_o  = element_count == DATA_DEPTH;
    assign empty_o = element_count == 0;

endmodule;