module multistage_mux #(
    parameter DATA_WIDTH,
    parameter SIZE,
    parameter REGISTERED_IN,
    parameter LUTX,
    parameter GRADE,

    ////////////////////////////////////////////////////////////////
    // Globally Defined Locally Set Parameters
    localparam                                      SELECTOR_WIDTH       = multistage_mux_SELECTOR_WIDTH(SIZE),
    localparam                                      GROUP_SELECTOR_WIDTH = multistage_mux_GROUP_SELECTOR_WIDTH(LUTX, GRADE),
    localparam                                      GROUP_SIZE           = multistage_mux_GROUP_SIZE(GROUP_SELECTOR_WIDTH),
    localparam                                      STAGES               = multistage_mux_STAGES(GROUP_SIZE),
    localparam int_t [SMALL - 1 : 0][SOLAR - 1 : 0] MUX_TREE_MAP         = multistage_mux_MUX_TREE_MAP(LUTX, GRADE, STAGES),
    localparam                                      LATENCY              = multistage_mux_LATENCY(REGISTERED_IN, STAGES)
) (
    input clk_i,

    input [SIZE - 1 : 0][DATA_WIDTH - 1 : 0]     data_i,
    input               [SELECTOR_WIDTH - 1 : 0] sel_i,

    output              [DATA_WIDTH - 1 : 0] data_o
);

    logic [SIZE - 1 : 0][DATA_WIDTH - 1 : 0] data;
    logic [SIZE - 1 : 0][DATA_WIDTH - 1 : 0] data_g;

    logic [SELECTOR_WIDTH - 1 : 0] sel;
    logic [SELECTOR_WIDTH - 1 : 0] sel_g;

    always@(posedge clk_i) begin
        data <= data_i;
        sel  <= sel_i;
    end

    assign data_g <= (REGISTERED_IN == 1) ? data : data_i;
    assign sel_g  <= (REGISTERED_IN == 1) ? sel : sel_i;

    
    // seperating it like this allows us to refer directly a combinational result
    // instead of just registered result
    logic [STAGES : 0][SIZE - 1 : 0][DATA_WIDTH - 1 : 0] mux_data;
    logic [STAGES : 0][SIZE - 1 : 0][DATA_WIDTH - 1 : 0] mux_data_pipeline;
    
    logic [STAGES : 0][SELECTOR_WIDTH - 1 : 0] sel_pipeline;
    
    /*
    So whilst I could have created another 'mux' module, it would be too modular in the sense that
    it would be circular in defintion. Meaning, a multistage_mux can be configured just as a simpler
    less parameterized 'mux', hence we do the hard work here in the generate statement.

    Flow is:

        mux_data_pipeline[row-1]..  -----|
                                         |
                                         |
                                         V
        mux_data_pipeline[row]... <----- mux_data[row]...    
        |                                |
        |                                |
        V                                V
        represents                  represents
        registered                  combinational
        output at that              output at that
        stage                       stage
    */
    
    generate
        assign mux_data[0]          = 'x;
        assign mux_data_pipeline[0] = data_g;

        sel_pipeline[0] = sel_g;

        for(genvar row = 1; row <= STAGES; row++) begin
            for(genvar col = 0; col < SIZE; col++) begin

                if(MUX_TREE_MAP[row][col] != 0) begin
                    logic [GROUP_SIZE - 1 : 0][DATA_WIDTH - 1 : 0]           group_mux_data;
                    logic                     [GROUP_SELECTOR_WIDTH - 1 : 0] sel;

                    // wire inputs
                    for(genvar i = 0; i < MUX_TREE_MAP[row - 1][col * GROUP_SIZE]; i++) begin
                        assign group_mux_data[i] = mux_data_pipeline[row - 1][(col * GROUP_SIZE) + i];
                    end

                    // fill don't cares for partial groups
                    for(genvar i_dont_care = MUX_TREE_MAP[row - 1][col * GROUP_SIZE]; i_dont_care < GROUP_SIZE; i_dont_care++) begin
                        assign group_mux_data[i_dont_care] = 'x;
                    end

                    // wire selector, unused bits are set to 0
                    for(genvar s = (row - 1) * GROUP_SELECTOR_WIDTH; (s < ((row - 1) * GROUP_SELECTOR_WIDTH + GROUP_SELECTOR_WIDTH)) && (s < SELECTOR_WIDTH); s++) begin
                        assign sel[s] = sel_pipeline[row - 1][s]; 
                    end

                    // fill in 0s for partial sel 
                    if()

                    // perform actual mux
                    assign mux_data[row][col] = group_mux_data[sel];
                end
            end

            // connect results down pipeline
            always@(posedge clk_i) begin
                mux_data_pipeline[row] <= mux_data[row];
                sel_pipeline[row] <= sel_pipeline[row - 1];            
            end
        end 
    endgenerate


    assign data_o = mux_data[STAGES];

endmodule