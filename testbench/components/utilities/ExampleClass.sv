/*
 * Example data encapsulation
 */

class ExampleClass #(
    parameter DATA_WIDTH
);
    logic [DATA_WIDTH - 1 : 0] a_i;
    logic [DATA_WIDTH - 1 : 0] d_o;

    function new ();
        this.a_i = 0;
        this.d_o = -1;
    endfunction
endclass