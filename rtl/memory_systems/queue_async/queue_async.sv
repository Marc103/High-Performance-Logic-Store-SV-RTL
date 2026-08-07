/*
Asynchronous Queue (aka AFIFO)

Simultaneous push/pop behavior to full/empty queue is undefined.
As usual, behavior to pushing to full queue or popping from empty 
queue is undefined.

Rules when using Asynchronous FIFOs
1. Read side can only operate on read signals and vice versa.
2. 'CDC bus-coherence constraints' must be applied 
    - see https://github.com/Marc103/async_fifo
    - otherwise undetectable in simulation bugs may appear on hardware
3. Reset signals coming from the opposite signals must be synchronized first
   before being used. The reset is also inverted then registered, adding a cycle
   of latency from respective time of reset, but in general when logic is being 
   reset, the reset should be held high for multiple cycles.
   - use 'sync_ptr.v' to do simple cdc for reset signals

ADDR_WIDTH:
- Sets the address width, also determines the data depth of the BRAM.

DATA_WIDTH:
- Data width.

REGISTERED_OUT_BRAM [0, 1]:
- If 1, outputs of internal bram are registered to an additional pipelined register, greatly
  reducing routing pressure to CLB fabric.

- the absence of 'REGISTERED_IN' or 'REGISTERED_IN_BRAM' is intentional because
  we can't tightly control the read latency, write latency and control state
  due to the asynchronous nature;
- but, we can still have a 'REGISTERED_OUT_BRAM' to allow an additional pipeline register
  on the read side since it only affects fetch latency
*/

import constant_functions_pkg::*;

module queue_async #(
    parameter ADDR_WIDTH,
    parameter DATA_WIDTH,
    parameter REGISTERED_OUT_BRAM,  // [0, 1]
    parameter SYNC_STAGES,

    ////////////////////////////////////////////////////////////////
    // Globally Defined Locally Set Parameters
    localparam WRITE_LATENCY = queue_async_WRITE_LATENCY(),
    localparam READ_LATENCY  = queue_async_READ_LATENCY(REGISTERED_OUT_BRAM)

) (
    // Write Side
    input wr_clk_i,
    input wr_rst_i,

    input                      push_i,
    input [DATA_WIDTH - 1 : 0] wr_data_i,
    output                     full_o,
    output                     one_space_left_o,

    // Read Side
    input rd_clk_i,
    input rd_rst_i,

    input                       pop_i,
    output [DATA_WIDTH - 1 : 0] rd_data_o,
    output                      empty_o,
    output                      one_item_left_o
);

    logic wr_rst_n;
    always@(posedge wr_clk_i) begin
        wr_rst_n <= ~wr_rst_i;
    end

    logic rd_rst_n;
    always@(posedge rd_clk_i) begin
        rd_rst_n <= ~rd_rst_i;
    end

    logic [DATA_WIDTH - 1 : 0] rd_data;

    async_fifo #(
        .DSIZE(DATA_WIDTH),
        .ASIZE(ADDR_WIDTH),
        .FALLTHROUGH("FALSE"),
        .SYNC_STAGES(SYNC_STAGES)
    ) afifo (
        // Write Side
        .wclk  (wr_clk_i),
        .wrst_n(wr_rst_n),
        .winc  (push_i),
        .wdata (wr_data_i),
        .wfull (full_o),
        .awfull(one_space_left_o),

        // Read Side
        .rclk(rd_clk_i),
        .rrst_n(rd_rst_n),
        .rinc(pop_i),
        .rdata(rd_data),
        .rempty(empty_o),
        .arempty(one_item_left_o)
    );

    logic [DATA_WIDTH - 1 : 0] rd_data_reg;
    always@(posedge rd_clk_i) begin
        rd_data_reg <= rd_data;
    end

    assign rd_data_o = (REGISTERED_OUT_BRAM == 1) ? rd_data_reg : rd_data;
endmodule