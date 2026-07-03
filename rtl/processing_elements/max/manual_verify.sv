"
    localparam LATENCY = max_LATENCY(REGISTERED_IN, GRADE)
"
- defined as
"
    function automatic int max_LATENCY(int REGISTERED_IN, int GRADE);
        int latency;
        if(GRADE == 2) begin
            latency = 1;
        end else if (GRADE == 1) begin
            latency = 2;
        end else begin // assume GRADE == 2
            latency = 1;
        end

        if(REGISTERED_IN == 1) latency++;

        return latency;
    endfunction
"
- correct arguments passed in
- initial grade determines latency, where grade 1 means per stage should use
  at most 1 logic level. Since there are two, compare and mux, it means we need
  2 stages. Thus grade 1 means 2 cycles of latency. With grade 2 we only need
  one stage, hence on cycle of latency.
- finally REGISTERED_IN if enabled adds an additional cycle of latency
[Marc103 + Codex 5.5 - 06/15/26]

"
    input clk_i,

    input [DATA_WIDTH - 1 : 0] data_a_i,
    input [DATA_WIDTH - 1 : 0] data_b_i,

    output [DATA_WIDTH - 1 : 0] data_o
"
- ports and respective bit widths are correct

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
- starting declarations are correct for first 4 statements
- correct sampling of inputs in sequential block
    - correct clk_i used
- assign conditions are correct
    - if registered in the data_*_g signals should be set to registered data_*
      signals, else, the immediate in data_*_i signals.
[Marc103 + Codex 5.5 - 06/15/26]

"
    logic unsigned [DATA_WIDTH - 1 : 0] data_a_us_g;
    logic unsigned [DATA_WIDTH - 1 : 0] data_b_us_g;
    logic unsigned [2:0][DATA_WIDTH - 1 : 0] data_a_us;
    logic unsigned [2:0][DATA_WIDTH - 1 : 0] data_b_us;

    logic signed [DATA_WIDTH - 1 : 0] data_a_s;
    logic signed [DATA_WIDTH - 1 : 0] data_b_s;

    logic mux_sel_g;
    logic [1:0] mux_sel;

    always_comb begin
        data_a_us_g = data_a_g[DATA_WIDTH - 1 : 0];
        data_b_us_g = data_b_g[DATA_WIDTH - 1 : 0];

        data_a_s = data_a_g[DATA_WIDTH - 1 : 0];
        data_b_s = data_b_g[DATA_WIDTH - 1 : 0];

        if(SIGNED == 1) begin
            mux_sel_g = data_b_s < data_a_s ? 1 : 0;
        end else begin
            mux_sel_g = data_b_us_g < data_a_us_g ? 1 : 0;
        end
    end
"
- starting declarations are correct for first 8 statements
    - we have the unsigned and signed respective declarations
    - we only pipeline the unsigned signals, the signed/unsigned
      logically remapping are just to determine the correct mux
      signalling, which happen on the first stage, ultimately we mux the unsigned signals.
    - since we can have up to 2 stages and at minimum 1 stage,
      [2 : 0] is wide enough for [1] 1 stage (cycle) later and [2] 2 stages
      (cycles) later.
    - data_*_us_g and mux_sel_g represent the current combinational stage 0
      values, kept separate from the registered pipeline arrays.
    - the mux_sel pipeline is [1:0] instead of [2:0] since it finishes by stage 1
[Marc103 + Codex 5.5 - 06/15/26]


"
    always@(posedge clk_i) begin
        if(GRADE == 1) begin
            data_a_us[1] <= data_a_us_g;
            data_b_us[1] <= data_b_us_g;

            data_a_us[2] <= mux_sel[1] ? data_a_us[1] : data_b_us[1];
        end else if(GRADE == 2) begin
            data_a_us[1] <= mux_sel_g ? data_a_us_g : data_b_us_g;
        end else begin
            data_a_us[1] <= mux_sel_g ? data_a_us_g : data_b_us_g;
        end
        mux_sel[1] <= mux_sel_g;
    end
"
- if GRADE == 1
    - data_*_us_g signals pipe forward to stage 1, [1]
    - mux_sel_g also pipes forward to stage 1, [1]
        - reminder that mux_sel_g is calculated in the always_comb block prior
    - then in stage 2, data_a_us[2] will hold the muxd signal as according to
      mux_sel[1]
    - check input values to mux, correct
- if GRADE == 2
    - data_a_us[1] will hold the muxd value as according to mux_sel_g
    - check input values to mux, correct
- else follows GRADE == 2 logic
[Marc103 + Codex 5.5 - 06/15/26]

"
    generate 
        if(GRADE == 1) begin
            assign data_o = data_a_us[2];
        end else if(GRADE == 2) begin
            assign data_o = data_a_us[1];
        end else begin
            assign data_o = data_a_us[1];
        end
    endgenerate
"
- if GRADE == 1, then we know the result will be at [2]
- if GRADE == 2, then we know the result will be at [1]
- else follow GRADE == 2 logic
- one and only output signal assigned
[Marc103 + Codex 5.5 - 06/15/26]
