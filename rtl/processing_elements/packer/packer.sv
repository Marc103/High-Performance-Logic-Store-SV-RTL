/*
Packer
Packs elements according to some defined word size, i.e
[a3, a2] <- [a1, a0] <- [b3, b2] <- [b1, b0] 
with a word size of 4 elements will output
cycle l + 0: [x, x, a3, a2]   packer_valid_o = 0
cycle l + 1: [a3, a2, a1, a0] packer_valid_o = 1
cycle l + 2: [a1, a0, b3, b2] packer_valid_o = 0
cycle l + 3: [b3, b2, b1, b0] packer_valid_o = 1
'l' is latency.

'sync_i' allows the packer to discern the starting point of packing.
  - This module was built to work with 'aligner', where 'match_o' would
    feed into its 'sync_i'

Two rules that must be followed:

1. EGRESS_SIZE >= INGRESS_SIZE

2. (EGRESS_SIZE % INGRESS_SIZE) == 0
  - this makes 'breaking off chunks' to form the EGRESS_SIZE simple as it sits
    at a fixed boundary and relieves the need of a somewhat complex fsm and mux circuit
  - if say, you need EGRESS_SIZE = 4, INGRESS_SIZE = 3, use 3 x 4 = 12 EGRESS SIZE. This will
    give you 3 words instead, but every 4 cycles, allowing you feed each word on it's own
    cycle for downstream logic (using a 'feeder' module, to be developed).

The latency describes number of posedges seen before packed element is ready from the
start of packing, then +1 if REGISTERED_IN is enabled. So if INGRESS_SIZE = 2, EGRESS_SIZE = 8,
REGISTERED_IN = 1, 8 / 2 = 4, 4 - 1 = 3, 3 + 1 = 4 latency cycles. 

DATA_WIDTH:
- Data width of one element

REGISTERED_IN [0, 1]:
- If 1, inputs are registered, increasing latency by 1 cycle,
  else, inputs are direct.

INGRESS_SIZE[1,..]:
- Number of elements per word entering, Two rules that must be followed:

EGRESS_SIZE[1,..]:
- Number of elements per word exiting, see 'Two rules that must be followed:'

*/

import constant_functions_pkg::*; 

module packer #(
    parameter REGISTERED_IN,
    parameter DATA_WIDTH,
    parameter INGRESS_SIZE,
    parameter EGRESS_SIZE,

    ////////////////////////////////////////////////////////////////
    // Globally Defined Locally Set Parameters 
    localparam STRIDE = packer_STRIDE(INGRESS_SIZE, EGRESS_SIZE),
    localparam LATENCY = packer_LATENCY(REGISTERED_IN, STRIDE)
) (
    input clk_i,

    input [INGRESS_SIZE - 1 : 0][DATA_WIDTH - 1 : 0] unpacked_i,
    input                                    sync_i,

    output [EGRESS_SIZE - 1 : 0][DATA_WIDTH - 1 : 0] packed_o,
    output                                   packer_valid_o
);

    logic [INGRESS_SIZE - 1 : 0][DATA_WIDTH - 1 : 0] unpacked;
    logic [INGRESS_SIZE - 1 : 0][DATA_WIDTH - 1 : 0] unpacked_g;

    logic sync;
    logic sync_g;

    always@(posedge clk_i) begin
        unpacked <= unpacked_i;
        sync <= sync_i;
    end

    assign unpacked_g = (REGISTERED_IN == 1) ? unpacked : unpacked_i;
    assign sync_g = (REGISTERED_IN == 1) ? sync : sync_i;

    logic strider_valid_o;

    fsm_strider_ohe #(
        .STRIDE(STRIDE)
    ) fsm_srider_ohe_inst (
        .clk_i(clk_i),
        .sync_i(sync_g),
        .strider_valid_o(strider_valid_o)
    );

    logic [STRIDE - 1 : 0][INGRESS_SIZE - 1 : 0][DATA_WIDTH - 1 : 0] data_pipeline;
    always@(posedge clk_i) begin
        data_pipeline[0] <= 'x;
        for(int r = 1; r < STRIDE; r++) begin
            if(r == 1) begin
                data_pipeline[r] <= unpacked_g;
            end else begin
                data_pipeline[r] <= data_pipeline[r - 1];

            end
        end
    end

    logic [EGRESS_SIZE - 1  : 0][DATA_WIDTH - 1 : 0] packed_xkeyword;
    always_comb begin
        for(int s = 0; s < STRIDE; s++) begin
            for(int i = 0; i < INGRESS_SIZE; i++) begin
                if(s == 0) begin
                    packed_xkeyword[(s * INGRESS_SIZE) + i] = unpacked_g[i];
                end else begin
                    packed_xkeyword[(s * INGRESS_SIZE) + i] = data_pipeline[s][i];
                end
            end
        end
    end

    assign packed_o       = (STRIDE == 1) ? unpacked_g : packed_xkeyword;
    assign packer_valid_o = strider_valid_o;

endmodule