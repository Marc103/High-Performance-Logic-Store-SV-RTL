`ifndef FSM_FFT_WRITER_INF
`define FSM_FFT_WRITER_INF
interface fsm_fft_writer_inf #(
    parameter DATA_WIDTH,
    parameter ADDR_WIDTH
) (input clk_i);
    logic rst_i = 1;
    logic [ADDR_WIDTH - 1 : 0] a_wr_addr_i, b_wr_addr_i;
    logic valid_i = 0;
    logic [DATA_WIDTH - 1 : 0] y0_i, y1_i;
    logic [ADDR_WIDTH - 1 : 0] wr_addr_o;
    logic [DATA_WIDTH - 1 : 0] wr_data_o;
    logic wr_en_o;
    logic [ADDR_WIDTH - 1 : 0] sampled_wr_addr;
    logic [DATA_WIDTH - 1 : 0] sampled_wr_data;
    logic sampled_wr_en;
    // Observe exactly what a synchronous memory consumes, before NBA updates.
    always @(posedge clk_i) begin
        sampled_wr_addr <= wr_addr_o;
        sampled_wr_data <= wr_data_o;
        sampled_wr_en <= wr_en_o;
    end
    logic start_sequence = 0, end_sequence = 0, end_last_sequence = 0, idle = 1;
endinterface
`endif
