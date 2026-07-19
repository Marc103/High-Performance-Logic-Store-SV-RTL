/*
FSM Strider, using One Hot Encoding
Output a valid signal every STRIDE cycles, with sync_i to synchronize the start.
I.e. STRIDE = 5
sync_i = 1, strider_valid_o = x (we don't know nor care) : cycle 0
sync_i = 0, strider_valid_o = 0                          : cycle 1
sync_i = 0, strider_valid_o = 0                          : cycle 2
sync_i = 0, strider_valid_o = 0                          : cycle 3
sync_i = 0, strider_valid_o = 1                          : cycle 4
sync_i = 0, strider_valid_o = 0                          : cycle 5
sync_i = 1, strider_valid_o = 0                          : cycle 6
sync_i = 0, strider_valid_o = 0                          : cycle 7
sync_i = 0, strider_valid_o = 0                          : cycle 8
sync_i = 0, strider_valid_o = 0                          : cycle 9
sync_i = 0, strider_valid_o = 1                          : cycle 10
sync_i = 0, strider_valid_o = 0                          : cycle 11
sync_i = 0, strider_valid_o = 0                          : cycle 12
sync_i = 0, strider_valid_o = 0                          : cycle 13
sync_i = 0, strider_valid_o = 0                          : cycle 14
sync_i = 0, strider_valid_o = 1                          : cycle 15
...
The synchronization is with respect to the data accompanying the sync_i signal,
hence, there is no REGISTERED_IN feature, as a correct integration would implicity
require 1 cycle addition pipelining of such data, which could lead to integration
bugs.

Accompanying valid bits with the data pipeline must be used in conjunction with 
'strider_valid_o' to determine truly valid outputs. This is cheaper than having a 
resettable/immediate startable fsm design and allows for one hot encoding. Hence is 
why the case of 'valid_o = x (we don't know nor care)' is fine.

Because OHE is used, it's recommended to not use this module when many states
are needed and instead look into using something like 'fsm_counter' (to be developed).

In the case that STRIDE = 1, strider_valid_o is simply kept asserted.

STRIDE [1,..]:
- For every STRIDE cycles, valid_o is asserted.

*/

import constant_functions_pkg::*; 

module fsm_strider_ohe #(
    parameter STRIDE,


    ////////////////////////////////////////////////////////////////
    // Globally Defined Locally Set Parameters 
    localparam SYNC_IDX = fsm_strider_ohe_SYNC_IDX(STRIDE)

) (
    input  clk_i,

    input  sync_i,

    output strider_valid_o
);
    logic [STRIDE - 1 : 0] one_hot_encoded;
    logic [STRIDE - 1 : 0] one_hot_encoded_next;

    always@(posedge clk_i) begin
        one_hot_encoded <= one_hot_encoded_next;
    end

    always_comb begin
        // 0th state
        if(sync_i) begin
            one_hot_encoded_next[0] = 0;    
        end else begin
            one_hot_encoded_next[0] = one_hot_encoded[STRIDE - 1];
        end
        
        // rest of states
        for(int i = 1; i < STRIDE; i++) begin
            if(sync_i && (i == SYNC_IDX)) begin
                one_hot_encoded_next[i] = 1;
            end else if(sync_i) begin
                one_hot_encoded_next[i] = 0;
            end else begin
                one_hot_encoded_next[i] = one_hot_encoded[i - 1];
            end
        end
    end

    assign strider_valid_o = (STRIDE == 1) ? 1 : one_hot_encoded[STRIDE - 1];
endmodule