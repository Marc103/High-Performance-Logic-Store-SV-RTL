/* 
Single port BRAM with NO_CHANGE behavior.

ADDR_WIDTH:
- Sets the address width, also determines the data depth of the BRAM.

DATA_WIDTH:
- Data width.

REGISTERED_IN [0,1]:
- If 1, inputs are first registered, increasing the latency by 1 cycle,
  else, inputs are direct.

REGISTERED_OUT [0, 1]:
- if 1, an additional set of output registers are pipelined, greatly reducing
  routing pressure from the BRAM to fabric logic. Increases latency by 1 cycle.
*/
import constant_functions_pkg::*; 
 
module bram_single_port #(
    parameter ADDR_WIDTH,
    parameter DATA_WIDTH,
    parameter REGISTERED_IN, // [0, 1]
    parameter REGISTERED_OUT, // [0, 1]

    ////////////////////////////////////////////////////////////////
    // Globally Defined Locally Set Parameters
    localparam DATA_DEPTH    = bram_single_port_DATA_DEPTH   (ADDR_WIDTH),
    localparam READ_LATENCY  = bram_single_port_READ_LATENCY (REGISTERED_IN, REGISTERED_OUT),
    localparam WRITE_LATENCY = bram_single_port_WRITE_LATENCY(REGISTERED_IN)
) (
    input                       clk_i,

    input                       en_i,
    input                       wr_en_i,
    input  [ADDR_WIDTH - 1 : 0] addr_i,
    input  [DATA_WIDTH - 1 : 0] wr_data_i,

    output [DATA_WIDTH - 1 : 0] rd_data_o
);
    logic [DATA_WIDTH - 1 : 0] bram [DATA_DEPTH];

    logic                      en;
    logic                      wr_en;
    logic [ADDR_WIDTH - 1 : 0] addr;
    logic [DATA_WIDTH - 1 : 0] wr_data;

    logic [DATA_WIDTH - 1 : 0] rd_data;
    logic [DATA_WIDTH - 1 : 0] rd_data_clb_fabric;

    always@(posedge clk_i) begin
        en      <= en_i;
        wr_en   <= wr_en_i;
        addr    <= addr_i;
        wr_data <= wr_data_i;
    end

    logic                      en_g;
    logic                      wr_en_g;
    logic [ADDR_WIDTH - 1 : 0] addr_g;
    logic [DATA_WIDTH - 1 : 0] wr_data_g;

    generate
        if(REGISTERED_IN == 1) begin
            assign en_g      = en;
            assign wr_en_g   = wr_en;
            assign addr_g    = addr;
            assign wr_data_g = wr_data;
        end else begin
            assign en_g      = en_i;
            assign wr_en_g   = wr_en_i;
            assign addr_g    = addr_i;
            assign wr_data_g = wr_data_i;
        end 
    endgenerate

    always@(posedge clk_i) begin
        if(en_g) begin
            if(wr_en_g) begin
                bram[addr_g] <= wr_data_g;
            end else begin
                rd_data <= bram[addr_g];
            end
        end

        rd_data_clb_fabric <= rd_data;
    end

    assign rd_data_o = (REGISTERED_OUT == 1) ? rd_data_clb_fabric : rd_data;
endmodule