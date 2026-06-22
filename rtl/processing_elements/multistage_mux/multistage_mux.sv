module multistage_mux #(
    parameter DATA_WIDTH,
    parameter SIZE,
    parameter REGISTERED_IN,
    parameter LUTX,
    parameter GRADE,

    ////////////////////////////////////////////////////////////////
    // Globally Defined Locally Set Parameters
    localparam                                      SELECTOR_WIDTH = multistage_mux_SELECTOR_WIDTH(SIZE),
    localparam                                      GROUP_SIZE     = multistage_mux_GROUP_SIZE(LUTX, GRADE),
    localparam                                      PADDED_SIZE    = multistage_mux_PADDED_SIZE(SIZE, GROUP_SIZE),
    localparam                                      STAGES         = multistage_mux_STAGES(GROUP_SIZE),
    localparam int_t [SMALL - 1 : 0][SOLAR - 1 : 0] MUX_TREE_MAP   = multistage_mux_MUX_TREE_MAP(LUTX, GRADE, STAGES),
    localparam                                      LATENCY        = multistage_mux_LATENCY(REGISTERED_IN, STAGES)
) (
    input clk_i,

    input [SIZE - 1 : 0][DATA_WIDTH - 1 : 0]     data_i,
    input               [SELECTOR_WIDTH - 1 : 0] sel_i,

    output              [DATA_WIDTH - 1 : 0] data_o
);

    logic [SIZE - 1 : 0][DATA_WIDTH - 1 : 0] data;
    logic [SIZE - 1 : 0][DATA_WIDTH - 1 : 0] data_g;

    always@(posedge clk_i) begin
        data <= data_i;
    end

    assign data_g <= (REGISTERED_IN == 1) ? data : data_i;

    
    logic [STAGES : 0][SIZE - 1 : 0][DATA_WIDTH - 1 : 0] mux_data;

    assign mux_data[0] = data_g;
    

    always@(posedge clk_i) begin
    
    end

endmodule