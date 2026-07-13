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

REGISTERED_IN [0, 1]:
- If 1, inputs are registered, increasing latency by 1 cycle,
  else, inputs are direct.
*/
import constant_functions_pkg::*; 

module multistage_fanout #(
    parameter DATA_WIDTH,
    parameter FANOUT_SIZE,
    parameter FANOUT_FACTOR,
    parameter REGISTERED_IN,

    ////////////////////////////////////////////////////////////////
    // Globally Defined Locally Set Parameters
    localparam STAGES            = multistage_fanout_STAGES           (FANOUT_FACTOR, FANOUT_SIZE),
    localparam FINAL_FANOUT_SIZE = multistage_fanout_FINAL_FANOUT_SIZE(FANOUT_FACTOR, STAGES),
    localparam LATENCY           = multistage_fanout_LATENCY          (REGISTERED_IN, STAGES)
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

    assign data_g = (REGISTERED_IN == 1) ? data : data_i;

    logic [STAGES : 0][FINAL_FANOUT_SIZE - 1 : 0][DATA_WIDTH - 1 : 0] data_stages; 
    logic [STAGES - 1 : 0][FINAL_FANOUT_SIZE - 1 : 0][DATA_WIDTH - 1 : 0] data_stages_pipeline;

    always_comb begin
        data_stages[0] = 'x;

        //fanout tree
        for(int row = 1; row <= STAGES; row++) begin
            for(int out = 0; out < (FANOUT_FACTOR ** (row - 1)); out++) begin
                for(int fan_out = 0; fan_out < FANOUT_FACTOR; fan_out++) begin
                    if(row == 1) begin
                        data_stages[row][(out * FANOUT_FACTOR) + fan_out] = data_g;
                    end else begin
                        data_stages[row][(out * FANOUT_FACTOR) + fan_out] = data_stages_pipeline[row - 1][out];
                    end
                end
            end
        end
    end

    always@(posedge clk_i) begin
        for(int row = 1; row < STAGES; row++) begin
            data_stages_pipeline[row] <= data_stages[row];
        end 
    end

    assign data_o = data_stages[STAGES];
endmodule
