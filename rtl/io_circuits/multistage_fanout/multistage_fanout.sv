/* 
Multistage Fanout
Accepts an input, exponential grows it by some 'FANOUT_FACTOR' until 
the desired number of outputs, 'FANOUT_SIZE' is reached. This is to deal with
fanout load on the wires. The latency is calculated as:

DATA_WIDTH:
- Data width.

FANOUT_SIZE:
- How large do you want the input signal to fanout to. This is then used to find
  the nearest exponential ceiling and determined by FINAL_FANOUT_SIZE. I.e 
  if FANOUT_SIZE = 10 and FANOUT_FACTOR = 4, then FINAL_FANOUT_SIZE = 16 (ceiling of 10 -> 16) 
  available outputs.

FANOUT_FACTOR:
- Factor of exponential growth for the signal to grow by at each stage.

IMMEDIATE_START_FANOUT [0, 1]:
- If 1, the input is fanouted immediately
  else, inputs are first registered, increasing latency by 1 cycle.
*/
import constant_functions_pkg::*; 

module multistage_fanout #(
    parameter DATA_WIDTH,
    parameter FANOUT_SIZE,
    parameter FANOUT_FACTOR,
    parameter IMMEDIATE_START_FANOUT,

    ////////////////////////////////////////////////////////////////
    // Globally Defined Locally Set Parameters
    localparam STAGES            = multistage_fanout_STAGES           (FANOUT_FACTOR, FANOUT_SIZE),
    localparam PRE_FANOUT_SIZE   = multistage_fanout_PRE_FANOUT_SIZE  (FANOUT_FACTOR, STAGES),
    localparam FINAL_FANOUT_SIZE = multistage_fanout_FINAL_FANOUT_SIZE(FANOUT_FACTOR, STAGES),
    localparam LATENCY           = multistage_fanout_LATENCY          (IMMEDIATE_START_FANOUT, STAGES)
) (
    input clk_i,

    input  [DATA_WIDTH - 1 : 0] data_i,

    output [FINAL_FANOUT_SIZE - 1 : 0][DATA_WIDTH - 1 : 0] data_o
);
    logic [STAGES - 1 : 0][PRE_FANOUT_SIZE - 1 : 0]  [DATA_WIDTH - 1 : 0] data_stages;
    logic                 [FINAL_FANOUT_SIZE - 1 : 0][DATA_WIDTH - 1 : 0] data_reg_o;

    always@(posedge clk_i) begin
        // entry
        data_stages[0][0] <= data_i;

        // fanout tree
        for(int stage = 0; stage < (STAGES - 1); stage++) begin
            for(int idx = 0; idx < (FANOUT_FACTOR ** stage); idx++) begin
                for(int fanout = 0; fanout < FANOUT_FACTOR; fanout++) begin
                    // condition for immediate fanout if enabled
                    if((stage == 0) && (IMMEDIATE_START_FANOUT == 1)) begin
                        data_stages[stage + 1][(idx * FANOUT_FACTOR) + fanout] <= data_i;
                    end else begin
                        data_stages[stage + 1][(idx * FANOUT_FACTOR) + fanout] <= data_stages[stage][idx];
                    end
                end
            end
        end
    end

    always_comb begin
        // final fanout wires
        for(int idx = 0; idx < PRE_FANOUT_SIZE; idx++) begin
            for(int fanout = 0; fanout < FANOUT_FACTOR; fanout++) begin
                if((IMMEDIATE_START_FANOUT == 1) && (STAGES == 1)) begin
                    data_reg_o[(idx * FANOUT_FACTOR) + fanout] = data_i;
                end else begin
                    data_reg_o[(idx * FANOUT_FACTOR) + fanout] = data_stages[STAGES-1][idx];
                end
            end
        end
    end

    assign data_o  = data_reg_o;
endmodule