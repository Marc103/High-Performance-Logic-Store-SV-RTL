/* 
Single port BRAM with NO_CHANGE behavior

ADDR_WIDTH:
- Sets the address width, also determines the data depth of the BRAM.

DATA_WIDTH:
- Data width.

REGISTERED_IN [0,1]:
- If 1, inputs are first registered, increasing the latency by 1 cycle,
  else, inputs are direct.
*/
 
module bram_single_port #(
    parameter ADDR_WIDTH,
    parameter DATA_WIDTH,
    parameter REGISTERED_IN, // [0, 1]

    ////////////////////////////////////////////////////////////////
    // Globally Defined Locally Set Parameters
    localparam DATA_DEPTH = bram_single_port_DATA_DEPTH(ADDR_WIDTH),
    localparam LATENCY    = bram_single_port_LATENCY   (REGISTERED_IN)

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
                rd_data      <= rd_data;
            end else begin
                rd_data <= bram[addr_g];
            end
        end else begin
            rd_data <= rd_data;
        end
    end

    assign rd_data_o = rd_data;
endmodule