/* 
Simple dual port BRAM.
Simultaneous read and write to same address is undefined behavior.
'0' is the write port, '1' is the read port.

ADDR_WIDTH:
- Sets the address width, also determines the data depth of the BRAM.

DATA_WIDTH:
- Data width.

REGISTERED_IN [0,1]:
- If 1, inputs are first registered, increasing the latency by 1 cycle,
  else, inputs are direct.
*/

module bram_dual_port_simple #(
    parameter ADDR_WIDTH,
    parameter DATA_WIDTH,
    parameter REGISTERED_IN, // [0, 1]

    ////////////////////////////////////////////////////////////////
    // Globally Defined Locally Set Parameters
    localparam DATA_DEPTH = bram_dual_port_simple_DATA_DEPTH(ADDR_WIDTH),
    localparam LATENCY    = bram_dual_port_simple_LATENCY   (REGISTERED_IN)
) (
    // write port
    input                       clk_0_i,
    input                       en_0_i,
    input                       wr_en_i,
    input  [ADDR_WIDTH - 1 : 0] wr_addr_i,
    input  [DATA_WIDTH - 1 : 0] wr_data_i,

    // read port
    input                       clk_1_i,
    input                       en_1_i,
    input  [ADDR_WIDTH - 1 : 0] rd_addr_i,

    output [DATA_WIDTH - 1 : 0] rd_data_o
);
    logic [DATA_WIDTH - 1 : 0] bram [DATA_DEPTH];

    // write port
    logic                      en_0;
    logic                      wr_en;
    logic [ADDR_WIDTH - 1 : 0] wr_addr;
    logic [DATA_WIDTH - 1 : 0] wr_data;

    always@(posedge clk_0_i) begin
        en_0    <= en_0_i;
        wr_en   <= wr_en_i;
        wr_addr <= wr_addr_i;
        wr_data <= wr_data_i;
    end

    logic                      en_0_g;
    logic                      wr_en_g;
    logic [ADDR_WIDTH - 1 : 0] wr_addr_g;
    logic [DATA_WIDTH - 1 : 0] wr_data_g;

    generate
        if(REGISTERED_IN == 1) begin
            assign en_0_g    = en_0;
            assign wr_en_g   = wr_en;
            assign wr_addr_g = wr_addr;
            assign wr_data_g = wr_data;
        end else begin
            assign en_0_g    = en_0_i;
            assign wr_en_g   = wr_en_i;
            assign wr_addr_g = wr_addr_i;
            assign wr_data_g = wr_data_i;
        end
    endgenerate

    always@(posedge clk_0_i) begin
        if(en_0_g) begin
            if(wr_en_g) begin
                bram[wr_addr_g] <= wr_data_g;
            end
        end
    end

    // read port
    logic                      en_1;
    logic [ADDR_WIDTH - 1 : 0] rd_addr;

    always@(posedge clk_1_i) begin
        en_1    <= en_1_i;
        rd_addr <= rd_addr_i;
    end

    logic                      en_1_g;
    logic [ADDR_WIDTH - 1 : 0] rd_addr_g;

    generate 
        if(REGISTERED_IN == 1) begin
            assign en_1_g    = en_1;
            assign rd_addr_g = rd_addr;
        end else begin
            assign en_1_g    = en_1_i;
            assign rd_addr_g = rd_addr_i;
        end
    endgenerate

    always@(posedge clk_1_i) begin
        if(en_1_g) begin
            rd_data <= bram[rd_addr_g];
        end else begin
            rd_data <= rd_data;
        end
    end

    assign rd_data_o = rd_data;
endmodule
