/* Multistage Fanout
 * Accepts an input, exponential grows it by some 'FANOUT_FACTOR' until 
 * the desired number of outputs, 'FANOUT_SIZE' is reached. This is to deal with
 * fanout load on the wires and introduces a clog base(FACTOR) (OUTPUT_SIZE)
 * latency.
 */

module multistage_fanout #(
    parameter DATA_WIDTH,
    parameter FANOUT_SIZE,
    parameter FANOUT_FACTOR,
    parameter IMMEDIATE_START_FANOUT = 0,

    ////////////////////////////////////////////////////////////////
    // Local parameters
    localparam STAGES            = fanout_stages(FANOUT_SIZE, FANOUT_FACTOR),
    localparam PRE_FANOUT_SIZE   = FANOUT_FACTOR ** STAGES,
    localparam FINAL_FANOUT_SIZE = FANOUT_FACTOR ** (STAGES + 1) 
) (
    input clk_i,

    input  [DATA_WIDTH - 1 : 0] data_i,
    input                       valid_i,

    output [DATA_WIDTH - 1 : 0] data_o  [FINAL_FANOUT_SIZE],
    output                      valid_o [FINAL_FANOUT_SIZE]
);
    logic [DATA_WIDTH - 1 : 0] data_stages [STAGES + 1][PRE_FANOUT_SIZE];
    logic [DATA_WIDTH - 1 : 0] data_reg_o              [FINAL_FANOUT_SIZE];

    logic [DATA_WIDTH - 1 : 0] valid_stages [STAGES + 1][PRE_FANOUT_SIZE];
    logic                      valid_reg_o              [FINAL_FANOUT_SIZE];

    always@(posedge clk_i) begin
        // entry
        data_stages[0][0] <= data_i;
        valid_stages[0][0] <= valid_i;

        // fanout tree
        for(int stage = 0; stage < STAGES; stage++) begin
            for(int idx = 0; idx < (FANOUT_FACTOR ** stage); idx++) begin
                for(int fanout = 0; fanout < FANOUT_FACTOR; fanout++) begin
                    // condition for immediate fanout if enabled
                    if((stage == 0) && (IMMEDIATE_START_FANOUT == 1)) begin
                        data_stages[stage + 1][(idx * FANOUT_FACTOR) + fanout] <= data_i;
                        valid_stages[stage + 1][(idx * FANOUT_FACTOR) + fanout] <= valid_i;
                    end else begin
                        data_stages[stage + 1][(idx * FANOUT_FACTOR) + fanout] <= data_stages[stage][idx];
                        valid_stages[stage + 1][(idx * FANOUT_FACTOR) + fanout] <= valid_stages[stage][idx];
                    end
                end
            end
        end
    end

    always_comb begin
        // final fanout wires
        for(int idx = 0; idx < (FANOUT_FACTOR ** STAGES); idx++) begin
            for(int fanout = 0; fanout < FANOUT_FACTOR; fanout++) begin
                data_reg_o[(idx * FANOUT_FACTOR) + fanout]  = data_stages[STAGES][idx];
                valid_reg_o[(idx * FANOUT_FACTOR) + fanout] = valid_stages[STAGES][idx];
            end
        end
    end

    assign data_o  = data_reg_o;
    assign valid_o = valid_reg_o;

endmodule