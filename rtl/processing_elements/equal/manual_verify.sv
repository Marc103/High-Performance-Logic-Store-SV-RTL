"
    localparam LATENCY = equal_LATENCY(REGISTERED_IN, GRADE)
"
- defined as
"
    function automatic int equal_LATENCY(int REGISTERED_IN, int GRADE);
        int latency;
        if(GRADE == 2) begin
            latency = 0;
        end else if (GRADE == 1) begin
            latency = 1;
        end else begin // assume GRADE == 2
            latency = 0;
        end
        if(REGISTERED_IN == 1) latency++;
        return latency;
    endfunction
"
- correct arguments passed in  
- if GRADE == 2 latency is 0, if GRADE == 1 latency is 1 else latency is 0
  (assumed GRADE == 2), then REGISTERED_IN adds another cycle if enabled.
[Marc103 + Codex 5.5 - 07/06/26]

"
    input clk_i,

    input [DATA_WIDTH - 1 : 0] data_a_i,
    input [DATA_WIDTH - 1 : 0] data_b_i,

    output eq_o
"
- signals present
- bit widths are correct 
[Marc103 + Codex 5.5 - 07/06/26]

"
    logic [DATA_WIDTH - 1 : 0] data_a;
    logic [DATA_WIDTH - 1 : 0] data_b;

    logic [DATA_WIDTH - 1 : 0] data_a_g;
    logic [DATA_WIDTH - 1 : 0] data_b_g;

    always@(posedge clk_i) begin
        data_a <= data_a_i;
        data_b <= data_b_i;
    end

    assign data_a_g = (REGISTERED_IN == 1) ? data_a : data_a_i;
    assign data_b_g = (REGISTERED_IN == 1) ? data_b : data_b_i;
"
- standard REGISTERED_IN procedure

"
    logic unsigned [DATA_WIDTH - 1 : 0] data_a_g_u;
    logic unsigned [DATA_WIDTH - 1 : 0] data_b_g_u;
    
    assign data_a_g_u = data_a_g[DATA_WIDTH - 1 : 0];
    assign data_b_g_u = data_b_g[DATA_WIDTH - 1 : 0];

    logic  c0;
    logic  c1;

    logic  d0;
    logic  d1;

    assign c0 = data_a_g_u < data_b_g_u;
    assign c1 = data_a_g_u > data_b_g_u;

    always@(posedge clk_i) begin
        d0 <= c0;
        d1 <= c1;
    end
"
- check types
- explicitly using unsigned for comparison operators
- c0, c1 are the combinational outputs then d0, d1 pipeline
  them so that we can separate it for GRADE == 1
[Marc103 + Codex 5.5 - 07/06/26]

"
    logic eq;
    always_comb begin
        if(GRADE == 1) begin
            eq = !(d0 | d1);
        end else if(GRADE == 2) begin
            eq = !(c0 | c1);
        end else begin // assume GRADE = 2
            eq = !(c0 | c1);
        end
    end

    assign eq_o = eq;
"
- logic is for GRADE == 1, we drive eq using pipelined d0, d1 instead of 
  combinational output c0 and c1.
- otherwise for GRADE == 2, we use c0 and c1 direct
- assign eq_o to eq. 
- the general logic is that !(A < B) && !(A > B) is the same as A == B
    - also same as !((A < B) | (A > B)) which is how i wrote it
[Marc103 + Codex 5.5 - 07/06/26]

- A general note about this design choice; 'Why not just use == directly? Inferring
  two adders seems quite wasteful' well,
  - the coarse LUT granularity makes balance tree design unnecessarily deep for FPGA
    implementation, causing overpipelining and thus it's better to use the double 
    adder design
  - in ASIC, we hope that the double adder design would be simplified to the appropriate
    XOR/AND balanced tree 
