`ifndef ???_INF 
    `define ???_INF
interface ???_inf #(
    parameter ???,

    ////////////////////////////////////////////////////////////////
    // Globally Defined Locally Set Parameters
    localparam ???
) (
    ???
);
    ???
    // testbench sequencing signals
    logic start_sequence;
    logic end_sequence;
    logic end_last_sequence;
    logic idle;
endinterface
`endif 