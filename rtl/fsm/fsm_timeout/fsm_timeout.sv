/*
FSM Timeout
Output a timeout signal after TIMEOUT cycle from the point at which the reset_timer_i is asserted.
The timer reaches then sits in its timed out condition until reset_timer_i is asserted again, and is
interruptable by the resest_timer_i. There is no explicit 'start_timer_i' signal and the state before
reset_timer_i is first asserted is unknown.

TIMEOUT [0,..]:
- Timeout after how many cycles? If 0 or 1, 'timeout_o' is kept asserted high.
*/
import constant_functions_pkg::*;

module fsm_timeout #(
    parameter TIMEOUT,

    ////////////////////////////////////////////////////////////////
    // Globally Defined Locally Set Parameters 
    localparam COUNTER_WIDTH = fsm_timeout_COUNTER_WIDTH(TIMEOUT)
) (
    input  clk_i,
    input  reset_timer_i,
    output timeout_o
);
    logic [COUNTER_WIDTH - 1 : 0] timer;
    logic timer_increment;

    always@(posedge clk_i) begin
        // see manual verify about the correctness of this latent timer_increment
        if(reset_timer_i) begin
            timer_increment <= 1;
        end else begin
            timer_increment <= timer > (TIMEOUT - 1);
        end
        
        if(reset_timer_i) begin
            timer <= 1; // timer resets to 1 (not 0)
        end else begin
            if(timer_increment) begin 
                timer <= timer;     // sits on timeout condition
            end else begin
                timer <= timer + 1; // timer increments
            end
        end
    end

    assign timeout_o = (TIMEOUT == 0) || (TIMEOUT == 1) ? 1 : timer > (TIMEOUT - 1);
endmodule