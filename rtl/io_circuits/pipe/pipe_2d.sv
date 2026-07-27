/*
Takes an input and pipelines for certain number of
'LATENCY' cycles (can be 0). Two dimensional.

DATA_WIDTH:
- Data width.

FIRST_DIMENSION [1, ...]:
- Number of data elements in the first dimension.

SECOND_DIMENSION [1, ...]:
- Number of data elements in the second dimension.

LATENCY [0,...]:
- How many cycles to delay the input data by?

"Pipe pipe! Where is the pipe!"
*/


module pipe_2d #(
    parameter DATA_WIDTH,
    parameter FIRST_DIMENSION,
    parameter SECOND_DIMENSION,
    parameter LATENCY
) (
    input clk_i,

    input  [SECOND_DIMENSION - 1 : 0][FIRST_DIMENSION - 1 : 0][DATA_WIDTH - 1 : 0] data_i,
    output [SECOND_DIMENSION - 1 : 0][FIRST_DIMENSION - 1 : 0][DATA_WIDTH - 1 : 0] data_o
);

    generate
        for(genvar cond = (LATENCY == 0); cond == 1; cond = 0) begin
            assign data_o = data_i;
        end
        for(genvar cond = (LATENCY != 0); cond == 1; cond = 0) begin
            logic [LATENCY : 1][SECOND_DIMENSION - 1 : 0][FIRST_DIMENSION - 1 : 0][DATA_WIDTH - 1 : 0] data;

            always@(posedge clk_i) begin
                data[1] <= data_i;
                for(int i = 2; i <= LATENCY; i++) begin
                    data[i] <= data[i - 1];
                end
            end

            assign data_o = data[LATENCY];
        end
    endgenerate

endmodule
