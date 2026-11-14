/*
Serialize one FFT butterfly's Y1/B and Y0/A writes onto a shared memory port.

DATA_WIDTH [>= 1]:
- Width of one memory word, including both real/imaginary fields when a complex
  sample is stored at each address. Connect packed Y0 and Y1 in the memory's order.
ADDR_WIDTH [>= 1]:
- Sample memory address width.

Input timing:
- A rising valid_i sampled while idle accepts a completed butterfly bundle.
  Both y0_i and y1_i, and the corresponding b_wr_addr_i, must be valid then.
- The corresponding a_wr_addr_i must be valid at the following rising clock.
  It may arrive one clock after B; the writer does not sample it prematurely.
- No additional hold is needed after each address's sampling clock. Address
  pipelines must align B with the result strobe and A with the following clock;
  a two-clock hold alone does not establish this alignment.
- Y0 is saved on acceptance. At the FFT adder's minimum four-clock interval,
  the next bundle can change Y0r before this bundle's second write is issued.

Output timing, with acceptance on edge T:
- After T:   wr_en_o=1, wr_addr_o=B, wr_data_o=Y1.
- After T+1: wr_en_o=1, wr_addr_o=A, wr_data_o=saved Y0.
- A synchronous memory samples these commands on T+1 and T+2, respectively.
  Consecutive high wr_en_o cycles are two separate writes.
- A new bundle may be accepted at T+2; the FFT cores' interval >=4 is sufficient.
  Longer gaps work. There is no queue/backpressure; strobes while busy are ignored.
  valid_i must be sampled low between accepted rising strobes; holding it high
  does not repeatedly launch the same bundle.

Reset is synchronous for the FSM and suppresses wr_en_o while asserted,
discarding any uncommitted write. Only controls reset; data/address registers hold.
*/

module fsm_fft_writer #(
    parameter DATA_WIDTH,
    parameter ADDR_WIDTH
) (
    input                              clk_i,
    input                              rst_i,

    input  [ADDR_WIDTH - 1 : 0]         a_wr_addr_i,
    input  [ADDR_WIDTH - 1 : 0]         b_wr_addr_i,
    input                              valid_i,
    input  [DATA_WIDTH - 1 : 0]         y0_i,
    input  [DATA_WIDTH - 1 : 0]         y1_i,

    output [ADDR_WIDTH - 1 : 0]         wr_addr_o,
    output [DATA_WIDTH - 1 : 0]         wr_data_o,
    output                             wr_en_o
);
    // Current values.
    typedef enum logic {IDLE, WRITE_A} state_t;
    state_t                            state;
    logic                              valid_previous;
    logic                              wr_en;
    logic [ADDR_WIDTH - 1 : 0]          wr_addr;
    logic [DATA_WIDTH - 1 : 0]          wr_data;
    logic [DATA_WIDTH - 1 : 0]          y0_saved;

    // Corresponding next values.
    state_t                            state_next;
    logic                              valid_previous_next;
    logic                              wr_en_next;
    logic [ADDR_WIDTH - 1 : 0]          wr_addr_next;
    logic [DATA_WIDTH - 1 : 0]          wr_data_next;
    logic [DATA_WIDTH - 1 : 0]          y0_saved_next;

    always @(posedge clk_i) begin
        state          <= state_next;
        valid_previous <= valid_previous_next;
        wr_en          <= wr_en_next;
        wr_addr        <= wr_addr_next;
        wr_data        <= wr_data_next;
        y0_saved       <= y0_saved_next;
    end

    assign wr_addr_o = wr_addr;
    assign wr_data_o = wr_data;
    assign wr_en_o = wr_en && !rst_i;

    always_comb begin
        state_next          = state;
        valid_previous_next = valid_i;
        wr_en_next          = 0;
        wr_addr_next        = wr_addr;
        wr_data_next        = wr_data;
        y0_saved_next       = y0_saved;

        if(rst_i) begin
            state_next          = IDLE;
            valid_previous_next = 0;
        end else begin
            case(state)
                IDLE: begin
                    if(valid_i && !valid_previous) begin
                        wr_addr_next  = b_wr_addr_i;
                        wr_data_next  = y1_i;
                        wr_en_next    = 1;
                        y0_saved_next = y0_i;
                        state_next    = WRITE_A;
                    end
                end
                WRITE_A: begin
                    wr_addr_next = a_wr_addr_i;
                    wr_data_next = y0_saved;
                    wr_en_next   = 1;
                    state_next   = IDLE;
                end
                default: state_next = IDLE;
            endcase
        end
    end

    initial begin
        if(DATA_WIDTH < 1) $fatal(1, "DATA_WIDTH must be positive");
        if(ADDR_WIDTH < 1) $fatal(1, "ADDR_WIDTH must be positive");
    end
endmodule
