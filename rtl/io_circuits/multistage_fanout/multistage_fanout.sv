/* 
Multistage Fanout
Accepts an input, exponential grows it by some 'FANOUT_FACTOR' until 
the desired number of outputs, 'FANOUT_SIZE' is reached. This is to deal with
fanout load on the wires. The latency is calculated as:

DATA_WIDTH:
- Data width.

FANOUT_SIZE [1, ...]:
- How large do you want the input signal to fanout to. This is then used to find
  the nearest exponential ceiling and determined by FINAL_FANOUT_SIZE. I.e 
  if FANOUT_SIZE = 10 and FANOUT_FACTOR = 4, then FINAL_FANOUT_SIZE = 16 (ceiling of 10 -> 16) 
  available outputs.

FANOUT_FACTOR [2, ...]:
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
    localparam FINAL_FANOUT_SIZE = multistage_fanout_FINAL_FANOUT_SIZE(FANOUT_FACTOR, STAGES),
    localparam LATENCY           = multistage_fanout_LATENCY          (IMMEDIATE_START_FANOUT, STAGES)
) (
    input clk_i,

    input  [DATA_WIDTH - 1 : 0] data_i,

    output [FINAL_FANOUT_SIZE - 1 : 0][DATA_WIDTH - 1 : 0] data_o
);
    
    logic [DATA_WIDTH - 1 : 0] data;
    logic [DATA_WIDTH - 1 : 0] data_g;

    always@(posedge clk_i) begin
        data <= data_i;
    end

    assign data_g = (IMMEDIATE_START_FANOUT == 1) ? data_i : data;

    logic [STAGES : 0][FINAL_FANOUT_SIZE - 1 : 0][DATA_WIDTH - 1 : 0] data_stages;

    always@(posedge clk_i) begin
        // fanout tree
        for(int stage = 1; stage <= STAGES; stage++) begin
            for(int out = 0; out < (FANOUT_FACTOR ** (stage - 1)); out++) begin
                for(int fan_out = 0; fan_out < FANOUT_FACTOR ** stage; fan_out++) begin
                    if(stage == 1) begin 
                        data_stages[stage][(out * FANOUT_FACTOR) + fan_out] <= data_g;
                    end else begin
                        data_stages[stage][(out * FANOUT_FACTOR) + fan_out] <= data_stages[stage - 1][out];
                    end
                end
            end
        end 
    end

    assign data_o  = (STAGES == 0) ? data_g : data_stages[STAGES];
endmodule