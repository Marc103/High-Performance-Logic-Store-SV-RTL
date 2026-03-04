/* Multistage Fanout
 * Accepts an input, exponential grows it by some 'FANOUT_FACTOR' until 
 * the desired number of outputs, 'FANOUT_SIZE' is reached. This is to deal with
 * fanout load on the wires. The latency is calculated as:
 *
 * if(IMMEDIATE_START_FANOUT == 1)
 *     STAGES - 1
 * else
 *     STAGES
 * 
 * localparam LATENCY is provided as the standard to how to calculate the total latency.
 */

module multistage_fanout #(
    parameter DATA_WIDTH,
    parameter FANOUT_SIZE,
    parameter FANOUT_FACTOR,
    parameter IMMEDIATE_START_FANOUT = 0,

    ////////////////////////////////////////////////////////////////
    // Local parameters
    localparam STAGES            = clog_base(FANOUT_FACTOR, FANOUT_SIZE),
    localparam PRE_FANOUT_SIZE   = FANOUT_FACTOR ** (STAGES - 1),
    localparam FINAL_FANOUT_SIZE = FANOUT_FACTOR ** STAGES,
    localparam LATENCY = (IMMEDIATE_START_FANOUT == 1) ? STAGES - 1 : STAGES  
) (
    input clk_i,

    input  [DATA_WIDTH - 1 : 0] data_i,
    input                       valid_i,

    output [DATA_WIDTH - 1 : 0] data_o  [FINAL_FANOUT_SIZE],
    output                      valid_o [FINAL_FANOUT_SIZE]
);
    logic [DATA_WIDTH - 1 : 0] data_stages [STAGES][PRE_FANOUT_SIZE];
    logic [DATA_WIDTH - 1 : 0] data_reg_o              [FINAL_FANOUT_SIZE];

    logic [DATA_WIDTH - 1 : 0] valid_stages [STAGES][PRE_FANOUT_SIZE];
    logic                      valid_reg_o              [FINAL_FANOUT_SIZE];

    always@(posedge clk_i) begin
        // entry
        data_stages[0][0] <= data_i;
        valid_stages[0][0] <= valid_i;

        // fanout tree
        for(int stage = 0; stage < (STAGES - 1); stage++) begin
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
        for(int idx = 0; idx < PRE_FANOUT_SIZE; idx++) begin
            for(int fanout = 0; fanout < FANOUT_FACTOR; fanout++) begin
                if((IMMEDIATE_START_FANOUT == 1) && (STAGES == 1)) begin
                    data_reg_o[(idx * FANOUT_FACTOR) + fanout]  = data_i;
                    valid_reg_o[(idx * FANOUT_FACTOR) + fanout] = valid_i;
                end else begin
                    data_reg_o[(idx * FANOUT_FACTOR) + fanout]  = data_stages[STAGES-1][idx];
                    valid_reg_o[(idx * FANOUT_FACTOR) + fanout] = valid_stages[STAGES-1][idx];
                end
            end
        end
    end

    assign data_o  = data_reg_o;
    assign valid_o = valid_reg_o;

endmodule