/*
Takes an input and pipelines for certain number of
'LATENCY' cycles (can be 0).

DATA_WIDTH:
- Data width.

LATENCY [0,...]:
- How many cycles to delay the input data by?

"Pipe pipe! Where is the pipe!"
*/


module pipe #(
    parameter DATA_WIDTH,
    parameter LATENCY
) (
    input clk_i,

    input  [DATA_WIDTH - 1 : 0] data_i,
    output [DATA_WIDTH - 1 : 0] data_o
);

    logic [LATENCY : 0][DATA_WIDTH - 1 : 0] data;

    assign data[0] = data_i;

    always@(posedge clk_i) begin
        for(int i = 1; i <= LATENCY; i++) begin
            data[i] <= data[i - 1];
        end
    end

    assign data_o = data[LATENCY];

endmodule