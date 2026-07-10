/* 
Priority Encoder
Well, it's a priority encoder. Parameters allow further customisation, 
i.e. registered_in, grade.. See details just below.

INPUT_DATA_WIDTH;
- data width of the priority input signal

REGISTERED_IN [0, 1]:
- If 1, inputs are registered, increasing latency by 1 cycle,
  else, inputs are direct.


LUTX [1,...]:
- Size of primitive LUTs and should be set to the primitive LUT size of FPGA.
  It is use to determine how wide we can encode the values. I.e a LUT6 can 
  encode in groups of 6, so a 12-bit priority would be encoded into two groups, 
  then a max tree formed to get the priority. A 6-bit priority would be directly
  mapped into a LUT6, not requiring a tree. Whilst you could set this to a LUT size bigger
  than your actual device LUT primitive, it would no longer follow the GRADE
  and it's up to synthesis tool behavior whether a chain or balanced tree
  would be generated, hence, not advisable. Setting it to smaller value would
  underutilize the LUTs and create unecessarily larger max tree (and hence larger latency),
  but would be more appropriate with ASICs targets, where there are no magical LUT primitives.

GRADE [1,2]:
- passed to the GRADE of the max components in the MAX tree.
*/

import constant_functions_pkg::*; 

module priority_encoder #(
    parameter INPUT_DATA_WIDTH,
    parameter REGISTERED_IN,
    parameter LUTX,
    parameter GRADE,
    
    ////////////////////////////////////////////////////////////////
    // Globally Defined Locally Set Parameters
    localparam                                     ENCODE_GROUPS              = priority_encoder_ENCODE_GROUPS      (INPUT_DATA_WIDTH, LUTX),
    localparam                                     ENCODE_DEPTH               = priority_encoder_ENCODE_DEPTH       (ENCODE_GROUPS),
    localparam int_t [SMALL - 1 : 0][SOLAR - 1: 0] ENCODE_MAX_TREE_MAP        = priority_encoder_ENCODE_MAX_TREE_MAP(ENCODE_GROUPS, ENCODE_DEPTH),
    localparam                                     ENCODE_FIRST_LAYER_LATENCY = max_LATENCY                         (1, GRADE),
    localparam                                     ENCODE_REST_LAYERS_LATENCY = max_LATENCY                         (0, GRADE),
    localparam                                     LATENCY                    = priority_encoder_LATENCY            (REGISTERED_IN, ENCODE_DEPTH, ENCODE_FIRST_LAYER_LATENCY, ENCODE_REST_LAYERS_LATENCY),
    localparam                                     OUTPUT_DATA_WIDTH          = priority_encoder_OUTPUT_DATA_WIDTH  (INPUT_DATA_WIDTH)
) (
    input clk_i,

    input  [INPUT_DATA_WIDTH - 1 : 0]  priority_i,

    output [OUTPUT_DATA_WIDTH - 1 : 0] priority_encoded_o
);

    logic [INPUT_DATA_WIDTH - 1 : 0] priority_xkeyword;
    logic [INPUT_DATA_WIDTH - 1 : 0] priority_xkeyword_g;

    always@(posedge clk_i) begin
        priority_xkeyword <= priority_i; 
    end

    assign priority_xkeyword_g = (REGISTERED_IN == 1) ? priority_xkeyword : priority_i;


    logic [ENCODE_GROUPS - 1 : 0][OUTPUT_DATA_WIDTH - 1 : 0] encoded;
    
    // encode values layer
    always_comb begin
        for(int group = 0; group < ENCODE_GROUPS; group++) begin
            encoded[group] = 0;
            for(int i = (group * LUTX); i < ((group + 1) * LUTX); i++) begin
                if(i < INPUT_DATA_WIDTH) begin // if within bounds check since last group may not be full
                    if(priority_xkeyword_g[i]) begin
                        encoded[group] = i;
                    end
                end
            end
        end
    end

    // priority tree (using max logic)
    /* 
    Due to lut technology dependancy, I decided to use max() instead of something like pass_left_if_not_zero() so that
    the design scales cleanly with respect to the GRADE chosen. A single LUT6 can accomodate reduction or of a 6-bit encoded 
    value to determine != 0, which is much better than comparison (accomplished via addition) which would use 6 LUT6 and the 
    accompanying fast carry adder circuitry. Regardless,

    1. slightly larger input would cause the logic delay to increase a level
        - It can be argued that it is very unlikely that someone would need a larger priority then 64-bits (since a 6-bit encoded 
          value corresponds to a 64-bit input priority). However, a LUT4 corresponds to a 16-bit priority, which isn't that large.
    2. GRADE == 1, underutilized trapped LUTs due to pipelining (it's *too* area efficient), but for GRADE == 2 (provided 1. isn't
       violated), it would be optimal.
    3. an ASIC design wouldn't even need LUTs for the addition, allowing a very area efficient implementation anyway
    */

    logic [ENCODE_DEPTH : 0][ENCODE_GROUPS - 1 : 0][OUTPUT_DATA_WIDTH - 1 : 0] priority_encoded;

    generate
        assign priority_encoded[0] = encoded;

        for(genvar row = 1; row <= ENCODE_DEPTH; row++) begin
            for(genvar col = 0; col < ENCODE_GROUPS; col++) begin
                for(genvar check_bound = (((col * 2) + 0) < ENCODE_GROUPS); 
                           check_bound == 1; 
                           check_bound = 0) begin
                    for(genvar left_right = (ENCODE_MAX_TREE_MAP[row - 1][(col * 2) + 0] & ENCODE_MAX_TREE_MAP[row - 1][(col * 2) + 1]);
                               left_right == 1;
                               left_right = 0)  begin // both 1s
                        if(row == 1) // first layer? we register inputs.
                            max #(
                                .DATA_WIDTH(OUTPUT_DATA_WIDTH),
                                .SIGNED(0),
                                .REGISTERED_IN(1),
                                .GRADE(GRADE)
                            ) max_part_first_layer (
                                .clk_i(clk_i),
                            
                                .data_a_i(priority_encoded[row - 1][(col * 2) + 0]),
                                .data_b_i(priority_encoded[row - 1][(col * 2) + 1]),

                                .data_o(priority_encoded[row][col])
                            );
                        else begin
                            max #(
                                .DATA_WIDTH(OUTPUT_DATA_WIDTH),
                                .SIGNED(0),
                                .REGISTERED_IN(0),
                                .GRADE(GRADE)
                            ) max_part_rest_layers (
                                .clk_i(clk_i),
                            
                                .data_a_i(priority_encoded[row - 1][(col * 2) + 0]),
                                .data_b_i(priority_encoded[row - 1][(col * 2) + 1]),

                                .data_o(priority_encoded[row][col])
                            );
                        end
                    end 
                    for(genvar left_only = (ENCODE_MAX_TREE_MAP[row - 1][(col * 2) + 0] & (!ENCODE_MAX_TREE_MAP[row - 1][(col * 2) + 1]));
                               left_only == 1;
                               left_only = 0) begin
                        if(row == 1) // first layer? we use ENCODE_FIRST_LAYER_LATENCY
                            pipe #(
                                .DATA_WIDTH(OUTPUT_DATA_WIDTH),
                                .LATENCY(ENCODE_FIRST_LAYER_LATENCY)
                            ) pipe_part_first_layer (
                                .clk_i(clk_i),
                            
                                .data_i(priority_encoded[row - 1][(col * 2) + 0]),

                                .data_o(priority_encoded[row][col])
                            );
                        else begin
                            pipe #(
                                .DATA_WIDTH(OUTPUT_DATA_WIDTH),
                                .LATENCY(ENCODE_REST_LAYERS_LATENCY)
                            ) pipe_part_rest_layers (
                                .clk_i(clk_i),
                            
                                .data_i(priority_encoded[row - 1][(col * 2) + 0]),

                                .data_o(priority_encoded[row][col])
                            );
                        end
                    end
                end
            end
        end
    endgenerate

    assign priority_encoded_o = priority_encoded[ENCODE_DEPTH][0];

endmodule
