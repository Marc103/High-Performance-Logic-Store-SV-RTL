package constant_functions_pkg;
    ////////////////////////////////////////////////////////////////
    //          Max-bounding localparams for packed arrays        //
    ////////////////////////////////////////////////////////////////
    localparam ONE       = 1;
    localparam TINY      = 8;
    localparam SMALL     = 16;
    localparam MEDIUM    = 32;
    localparam LARGE     = 64;
    localparam MASSIVE   = 128;
    localparam PLANETARY = 256;
    localparam SOLAR     = 512;
    localparam GALACTIC  = 1024;

    ////////////////////////////////////////////////////////////////
    //                       Module IDs                           //
    ////////////////////////////////////////////////////////////////
    typedef enum int {
        BRAM_SINGLE_PORT,
        BRAM_DUAL_PORT_SIMPLE,
        MULTISTAGE_FANOUT,
        ALTERNATE_BASE_FP_ADDER,
        QUEUE,
        MAX,
        PRIORITY_ENCODER
    } module_id_e;
    
    typedef logic signed [31:0] int_t;

    ////////////////////////////////////////////////////////////////
    //          Non-module specific constant functions            //
    //////////////////////////////////////////////////////////////// 


    function automatic int clog_base(int base, int value);
        int exponent = 0;
        int acc = base ** 0;

        // Some sanity checks to prevent forever loop
        if(base <= 1)  $fatal("base is 1 or negative: %d", base);
        if(value <= 0) $fatal("value is zero or negative: %d", value);

        while(acc < value) begin
            acc = acc * base;
            exponent++;
        end

        return exponent;
    endfunction

    function automatic int mux_ability(int LUTX);
        int selector_width;
        selector_width = SMALL;
        
        // sanity check, the smallest is a 2:1 mux
        if(LUTX < 3) return 1;

        while((selector_width + (2**selector_width)) > LUTX) begin
            selector_width--;
        end

        return selector_width;
    endfunction

    ////////////////////////////////////////////////////////////////
    //            Module specific oversized structs               //
    //////////////////////////////////////////////////////////////// 

    ////////////////////////////////////////////////////////////////
    // bram_single_port
    typedef struct packed {
        int ADDR_WIDTH;
        int DATA_WIDTH;
        int REGISTERED_IN;
    } bram_single_port_pt;

    typedef struct packed {
        logic clk_i;

        logic                   en_i;
        logic                   wr_en_i;
        logic [SMALL - 1 : 0]   addr_i;
        logic [MASSIVE - 1 : 0] wr_data_i;

        logic [MASSIVE - 1 : 0] rd_data_o;
    } bram_single_port_t;

    ////////////////////////////////////////////////////////////////
    // bram_dual_port_simple
    typedef struct packed {
        int ADDR_WIDTH;
        int DATA_WIDTH;
        int REGISTERED_IN;
    } bram_dual_port_simple_pt;

    typedef struct packed {
        logic                   clk_0_i;
        logic                   en_0_i;
        logic                   wr_en_i;
        logic [SMALL - 1 : 0]   wr_addr_i;
        logic [MASSIVE - 1 : 0] wr_data_i;

        logic                 clk_1_i;
        logic                 en_1_i;
        logic [SMALL - 1 : 0] rd_addr_i;
        
        logic [MASSIVE - 1 : 0] rd_data_o;
    } bram_dual_port_simple_t;

    ////////////////////////////////////////////////////////////////
    // multistage_fanout
    typedef struct packed {
        int DATA_WIDTH;
        int FANOUT_SIZE;
        int FANOUT_FACTOR;
        int IMMEDIATE_START_FANOUT;
    } multistage_fanout_pt;

    typedef struct packed {
        logic clk_i;

        logic [GALACTIC - 1 : 0] data_i;

        logic [SOLAR - 1 : 0][GALACTIC - 1 : 0] data_o;
    } multistage_fanout_t;

    `define MULTISTAGE_FANOUT_IO_IN_STRUCT(DATA_WIDTH) \
    typedef struct packed { \
        logic                            [DATA_WIDTH - 1 : 0] data_i; \
    } multistage_fanout_io_in_t;

    `define MULTISTAGE_FANOUT_IO_OUT_STRUCT(DATA_WIDTH, FINAL_FANOUT_SIZE) \
    typedef struct packed { \
        logic [FINAL_FANOUT_SIZE - 1 : 0][DATA_WIDTH - 1 : 0] data_o; \
    } multistage_fanout_io_out_t;

    ////////////////////////////////////////////////////////////////
    // queue
    typedef struct packed {
        int ADDR_WIDTH;
        int DATA_WIDTH;
        int REGISTERED_IN;
        int REGISTERED_IN_BRAM;
        int READ_THEN_WRITE;
        int NUMBER_OF_QUEUES;
    } queue_pt;

    typedef struct packed {
        logic clk_i;
        logic rst_i;

        // write port
        logic                                      push_i;
        logic  [MEDIUM - 1 : 0][PLANETARY - 1 : 0] wr_data_i;

        // read port
        logic                                     pop_i;
        logic [MEDIUM - 1 : 0][PLANETARY - 1 : 0] rd_data_o;

        // conditions
        logic                      full_o;
        logic                      empty_o;

        logic  [MEDIUM : 0]    less_than_i; 
        logic                  less_than_o; // less than 'less_than_i' elements on queue

        logic  [MEDIUM : 0]    more_than_i;
        logic                  more_than_o; // more than 'more_than_i' elements on the queue
    } queue_t;

    `define QUEUE_IO_IN_STRUCT(NUMBER_OF_QUEUES, DATA_WIDTH, ADDR_WIDTH) \
    typedef struct packed { \
        logic rst_i; \
        \
        /* write port */ \
        logic push_i; \
        logic [NUMBER_OF_QUEUES-1:0][DATA_WIDTH-1:0] wr_data_i; \
        \
        /* read port */ \
        logic pop_i; \
        \
        /* conditions */ \
        logic [ADDR_WIDTH:0] less_than_i; \
        logic [ADDR_WIDTH:0] more_than_i; \
    } queue_io_in_t;

    `define QUEUE_IO_OUT_STRUCT(NUMBER_OF_QUEUES, DATA_WIDTH, ADDR_WIDTH) \
    typedef struct packed { \
        /* read port */ \
        logic [NUMBER_OF_QUEUES-1:0][DATA_WIDTH-1:0] rd_data_o; \
        \
        /* conditions */ \
        logic full_o; \
        logic empty_o; \
        \
        logic                 less_than_o; \
        logic                 more_than_o; \
    } queue_io_out_t;

    ////////////////////////////////////////////////////////////////
    // alternate base fp


    ////////////////////////////////////////////////////////////////
    // max
    typedef struct packed {
        int DATA_WIDTH;
        int SIGNED;
        int REGISTERED_IN;
        int GRADE;
    } max_pt;

    typedef struct packed {
        logic clk_i;

        logic [SOLAR - 1 : 0] data_a_i;

        logic [SOLAR - 1 : 0] data_o;
    } max_t;

    `define MAX_IO_IN_STRUCT(DATA_WIDTH) \
    typedef struct packed { \
        logic [DATA_WIDTH - 1 : 0] data_a_i; \
        logic [DATA_WIDTH - 1 : 0] data_b_i; \
    } max_io_in_t;

    `define MAX_IO_OUT_STRUCT(DATA_WIDTH) \
    typedef struct packed { \
        logic [DATA_WIDTH - 1 : 0] data_o; \
    } max_io_out_t;

    ////////////////////////////////////////////////////////////////
    // priority encoder
    typedef struct packed {
        int INPUT_DATA_WIDTH;
        int REGISTERED_IN;
        int REVERSED;
        int LUTX;
        int GRADE;
    } priority_encoder_pt;

    typedef struct packed {
        logic clk_i;

        logic [SOLAR - 1 : 0] priority_i;

        logic [SMALL - 1 : 0] priority_encoded_o;
    } priority_encoder_t;

    `define PRIORITY_ENCODER_IO_IN_STRUCT(INPUT_DATA_WIDTH) \
    typedef struct packed { \
        logic [INPUT_DATA_WIDTH - 1 : 0] priority_i; \
    } priority_encoder_io_in_t;

    `define PRIORITY_ENCODER_IO_OUT_STRUCT(OUTPUT_DATA_WIDTH) \
    typedef struct packed { \
        logic [OUTPUT_DATA_WIDTH - 1 : 0] priority_encoded_o; \
    } priority_encoder_io_out_t;

    ////////////////////////////////////////////////////////////////
    // multistage mux
    typedef struct packed {
        int DATA_WIDTH;
        int INPUT_SIZE;
        int REGISTERED_IN;
        int LUTX;
        int GRADE;
    } multistage_mux_pt;

    typedef struct packed {
        input clk_i,

        input [SOLAR - 1 : 0][GALACTIC - 1 : 0] data_i,
        input                [SMALL - 1 : 0]    sel_i,

        output               [GALACTIC - 1 : 0] data_o
    } multistage_mux_t;

    `define MULTISTAGE_MUX_IO_IN_STRUCT(DATA_WIDTH, SIZE, SELECTOR_WIDTH) \
    typedef struct packed { \
        logic [SIZE - 1 : 0][DATA_WIDTH - 1 : 0]     data_i; \
        logic               [SELECTOR_WIDTH - 1 : 0] sel_i;
    } multistage_mux_io_in_t;

    `define MULTISTAGE_MUX_IO_OUT_STRUCT(DATA_WIDTH) \
    typedef struct packed { \
        logic [DATA_WIDTH - 1 : 0] data_o; \
    } multistage_mux_io_out_t;

    ////////////////////////////////////////////////////////////////
    //           Module specific constant functions               //
    ////////////////////////////////////////////////////////////////


    ////////////////////////////////////////////////////////////////
    // bram_single_port
    function automatic int bram_single_port_DATA_DEPTH(int ADDR_WIDTH);
        return (2 ** ADDR_WIDTH);
    endfunction

    function automatic int bram_single_port_READ_LATENCY(int REGISTERED_IN, int REGISTERED_OUT);
        int latency = 1;
        if(REGISTERED_IN == 1)  latency++;
        if(REGISTERED_OUT == 1) latency++;
        return latency;
    endfunction


    function automatic int bram_single_port_WRITE_LATENCY(int REGISTERED_IN);
        int latency = 1;
        if(REGISTERED_IN == 1)  latency++;
        return latency;
    endfunction

    ////////////////////////////////////////////////////////////////
    // bram_dual_port_simple
    function automatic int bram_dual_port_simple_DATA_DEPTH(int ADDR_WIDTH);
        return (2 ** ADDR_WIDTH);
    endfunction

    function automatic int bram_dual_port_simple_READ_LATENCY(int REGISTERED_IN, int REGISTERED_OUT);
        int latency = 1;
        if(REGISTERED_IN == 1)  latency++;
        if(REGISTERED_OUT == 1) latency++;
        return latency;
    endfunction


    function automatic int bram_dual_port_simple_WRITE_LATENCY(int REGISTERED_IN);
        int latency = 1;
        if(REGISTERED_IN == 1)  latency++;
        return latency;
    endfunction

    ////////////////////////////////////////////////////////////////
    // multistage_fanout
    function automatic int multistage_fanout_STAGES(int FANOUT_FACTOR, int FANOUT_SIZE);
        return clog_base(FANOUT_FACTOR, FANOUT_SIZE);
    endfunction

    function automatic int multistage_fanout_FINAL_FANOUT_SIZE(int FANOUT_FACTOR, int STAGES);
        return (FANOUT_FACTOR ** STAGES);
    endfunction

    function automatic int multistage_fanout_LATENCY(int IMMEDIATE_START_FANOUT, int STAGES);
        int latency; 
        if(IMMEDIATE_START_FANOUT == 1) begin
            latency = 0;
        end else begin
            latency = 1;
        end
        latency = latency + STAGES;
        return latency;
    endfunction

    ////////////////////////////////////////////////////////////////
    // queue
    function automatic int queue_DATA_DEPTH(int ADDR_WIDTH);
        return (2 ** ADDR_WIDTH);
    endfunction

    function automatic int queue_READ_LATENCY(int CONFLICT_PROOF, int REGISTERED_IN, REGISTERED_IN_BRAM, REGISTERED_OUT_BRAM);
        int latency = bram_dual_port_simple_READ_LATENCY(REGISTERED_IN_BRAM, REGISTERED_OUT_BRAM);
        if(CONFLICT_PROOF == 1) latency++;
        if(REGISTERED_IN == 1)  latency++;
        return latency;
    endfunction

    function automatic int queue_WRITE_LATENCY(int CONFLICT_PROOF, int REGISTERED_IN, REGISTERED_IN_BRAM);
        int latency = bram_dual_port_simple_WRITE_LATENCY(REGISTERED_IN_BRAM);
        if(CONFLICT_PROOF == 1) latency++;
        if(REGISTERED_IN == 1)  latency++;
        return latency;
    endfunction

    ////////////////////////////////////////////////////////////////
    // alternate_base_fp_adder
    function automatic int alternate_base_fp_adder_(int EXP_WIDTH, int MANT_WIDTH);
        return (1 + EXP_WIDTH + MANT_WIDTH);
    endfunction

    function automatic int alternate_base_fp_adder_LATENCY(int PIPE_REG_0, int PIPE_REG_1, int PIPE_REG_2, int PIPE_REG_3);
        int a = 0;
        if(PIPE_REG_0 == 1) a += 1;
        if(PIPE_REG_1 == 1) a += 1;
        if(PIPE_REG_2 == 1) a += 1;
        if(PIPE_REG_3 == 1) a += 1;
        return a;
    endfunction

    function automatic int alternate_base_fp_DATA_WIDTH(int EXP_WIDTH, int MANT_WIDTH);
        return (1 + EXP_WIDTH + MANT_WIDTH);
    endfunction

    function automatic int alternate_base_fp_BASE_WIDTH(int BASE);
        return clog_base(2, BASE);
    endfunction

    function automatic int alternate_base_fp_STICKY_WIDTH(int MANT_WIDTH, int BASE_WIDTH);
        return (MANT_WIDTH - BASE_WIDTH - 1);
    endfunction

    function automatic int alternate_base_fp_DATA_WIDTH_EXT_0(int EXP_WIDTH, int MANT_WIDTH, int BASE_WIDTH, int STICKY_WIDTH);
        return (1 + EXP_WIDTH + MANT_WIDTH + BASE_WIDTH + 1 + STICKY_WIDTH);
    endfunction

    function automatic int alternate_base_fp_DATA_WIDTH_EXT_1(int EXP_WIDTH, int MANT_WIDTH, int BASE_WIDTH);
        return (1 + EXP_WIDTH + MANT_WIDTH + BASE_WIDTH + 1 + 1);
    endfunction

    ////////////////////////////////////////////////////////////////
    // max
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

    ////////////////////////////////////////////////////////////////
    // priority encoder
    function automatic int priority_encoder_ENCODE_GROUPS(int INPUT_DATA_WIDTH, int LUTX);
        int encode_groups;
        encode_groups = INPUT_DATA_WIDTH / LUTX; // truncation towards 0, safe
        if((INPUT_DATA_WIDTH % LUTX) != 0) begin // if not perfectly divisible
            encode_groups++;
        end
        return encode_groups;
    endfunction

    function automatic int priority_encoder_ENCODE_DEPTH(int ENCODE_GROUPS);
        return $clog2(ENCODE_GROUPS);
    endfunction

    function automatic int_t [SMALL - 1 : 0][SOLAR - 1 : 0] priority_encoder_ENCODE_MAX_TREE_MAP(int ENCODE_GROUPS, int ENCODE_DEPTH);
        int_t [SMALL - 1 : 0][SOLAR - 1 : 0] max_tree_map;

        // initialize all values to 0
        for(int r = 0; r < SMALL; r++) begin
            for(int c = 0; c < SOLAR; c++) begin
                max_tree_map = 0;
            end
        end
        
        // set 0th row to 1s for each group
        for(int group = 0; group < ENCODE_GROUPS; group++) begin
            max_tree_map[0][group] = 1;
        end

        // determine tree for rest of rows ( <= ENCODE_DEPTH is intentional)
        for(int row = 1; row <= ENCODE_DEPTH; row++) begin
            for(int col = 0; col < ENCODE_GROUPS; col++) begin
                if(((col * 2) + 0) >= ENCODE_GROUPS) break;
                if(max_tree_map[row - 1][(col * 2) + 0] | max_tree_map[row - 1][(col * 2) + 1]) begin
                    max_tree_map[row][col] = 1;
                end
            end
        end

        return  max_tree_map;
    endfunction
    
    function automatic int priority_encoder_LATENCY(int REGISTERED_IN, int ENCODE_DEPTH, int ENCODE_FIRST_LAYER_LATENCY, int ENCODE_REST_LAYERS_LATENCY);
        int latency = 0;
        if(REGISTERED_IN == 1) latency++;
        if(ENCODE_DEPTH >= 1) latency += ENCODE_FIRST_LAYER_LATENCY;
        if(ENCODE_DEPTH >= 2) latency += (ENCODE_REST_LAYERS_LATENCY * (ENCODE_DEPTH - 1));
        return latency;
    endfunction

    function automatic int priority_encoder_OUTPUT_DATA_WIDTH(int INPUT_DATA_WIDTH);
        return $clog2(INPUT_DATA_WIDTH);
    endfunction

    ////////////////////////////////////////////////////////////////
    // multistage mux
    function automatic int multistage_mux_SELECTOR_WIDTH(int SIZE);
        return $clog2(SIZE);
    endfunction

    function automatic int multistage_mux_GROUP_SIZE(LUTX, GRADE);
        int mux_ability, graded_mux_ability, group_size;

        mux_ability = mux_ability(LUTX);
        graded_mux_ability = mux_ability * GRADE;

        group_size = 2 ** graded_mux_ability;

        return group_size;
    endfunction

    function automatic int multistage_

    function automatic int multistage_mux_STAGES(int GROUP_SIZE, SIZE);
        return clog_base(GROUP_SIZE, SIZE);
    endfunction

    function automatic int_t [SMALL - 1 : 0][SOLAR - 1 : 0] multistage_mux_MUX_TREE_MAP(int STAGES, int GROUP_SIZE, int SIZE);
        int_t [SMALL - 1 : 0][SOLAR - 1 : 0] mux_tree_map;
        int counter;
        
        // initialize all values to 0
        for(int r = 0; r < SMALL; r++) begin
            for(int c = 0; c < SOLAR; c++) begin
                mux_tree_map = 0;
            end
        end

        // set 0th row to 1s for each input 
        for(int input = 0; input < SIZE; input++) begin
            mux_tree_map[0][input] = 1;
        end

        // *we set the lowest index for each group the number of actual inputs available
        // and is used to deal with partial groups

        for(int group = 0; group < SIZE; group += GROUP_SIZE) begin
            counter = 0;
            for(int g = 0; g < GROUP_SIZE; g++) begin
                if(mux_tree_map[0][group + g] != 0) counqter++
            end
            mux_tree_map[0][group] == counter;
        end


        // mux tree, repeat the two steps above for each proceeding stage
        for(int row = 1; row <= STAGES; row++) begin
            for(int col = 0; col < SIZE; col++) begin
                if(((col * GROUP_SIZE) + 0) >= SIZE) break;

                // check if there are inputs from previous row to mux, 
                // set as 1 in current row if there is
                if(mux_tree_map[row - 1][((col * GROUP_SIZE) + 0)] != 0) begin
                    mux_tree_map[row][col] = 1;
                end
            end

            // set group completness in the current row, in the lowest index *
            for(int group = 0; group < SIZE; group += GROUP_SIZE) begin
                counter = 0;
                for(int g = 0; g < GROUP_SIZE; g++) begin
                    if(mux_tree_map[row][group + g] != 0) counter++
                end
            end
        end
        
    endfunction


endpackage
