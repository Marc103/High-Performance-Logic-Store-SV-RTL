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
        NO_MODULE,
        BRAM_SINGLE_PORT,
        BRAM_DUAL_PORT_SIMPLE,
        MULTISTAGE_FANOUT,
        ALTERNATE_BASE_FP_ADDER,
        QUEUE,
        MAX,
        PRIORITY_ENCODER,
        MULTISTAGE_MUX,
        EQUAL,
        REDUCTION_TREE,
        ALIGNER,
        RESERVOIR,
        QUEUE_ASYNC
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

    function automatic int_t [SMALL - 1 : 0][SOLAR - 1 : 0] generic_tree_map(int STAGES, int GROUP_SIZE, int SIZE);
        int_t [SMALL - 1 : 0][SOLAR - 1 : 0] tree_map;
        int counter;
        
        // initialize all values to 0
        for(int r = 0; r < SMALL; r++) begin
            for(int c = 0; c < SOLAR; c++) begin
                tree_map[r][c] = 0;
            end
        end

        // set 0th row to 1s for each input 
        for(int i = 0; i < SIZE; i++) begin
            tree_map[0][i] = 1;
        end

        // *we set the lowest index for each group the number of actual inputs available
        // and is used to deal with partial groups

        for(int group = 0; group < SIZE; group += GROUP_SIZE) begin
            counter = 0;
            for(int g = 0; g < GROUP_SIZE; g++) begin
                if(tree_map[0][group + g] != 0) counter++;
            end
            tree_map[0][group] = counter;
        end


        // tree, repeat the two steps above for each proceeding stage
        for(int row = 1; row <= STAGES; row++) begin
            for(int col = 0; col < SIZE; col++) begin
                if(((col * GROUP_SIZE) + 0) >= SIZE) break;

                // check if there are inputs from previous row to mux, 
                // set as 1 in current row if there is
                if(tree_map[row - 1][((col * GROUP_SIZE) + 0)] != 0) begin
                    tree_map[row][col] = 1;
                end
            end

            // set group completness in the current row, in the lowest index *
            for(int group = 0; group < SIZE; group += GROUP_SIZE) begin
                counter = 0;
                for(int g = 0; g < GROUP_SIZE; g++) begin
                    if(tree_map[row][group + g] != 0) counter++;
                end
                tree_map[row][group] = counter;
            end
        end

        return tree_map;
    endfunction

    function automatic int max(int a, int b);
        return (a > b) ? a : b;
    endfunction

    function automatic int min(int a, int b);
        return (a < b) ? a : b;
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
        int REGISTERED_IN;
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

    `define QUEUE_IO_IN_STRUCT(DATA_WIDTH, ADDR_WIDTH) \
    typedef struct packed { \
        logic rst_i; \
        \
        /* write port */ \
        logic push_i; \
        logic [DATA_WIDTH-1:0] wr_data_i; \
        \
        /* read port */ \
        logic pop_i; \
        \
        /* conditions */ \
        logic [ADDR_WIDTH:0] less_than_i; \
        logic [ADDR_WIDTH:0] more_than_i; \
    } queue_io_in_t;

    `define QUEUE_IO_OUT_STRUCT(DATA_WIDTH, ADDR_WIDTH) \
    typedef struct packed { \
        /* read port */ \
        logic [DATA_WIDTH-1:0] rd_data_o; \
        \
        /* conditions */ \
        logic full_o; \
        logic empty_o; \
        \
        logic                 less_than_o; \
        logic                 more_than_o; \
    } queue_io_out_t;

    ////////////////////////////////////////////////////////////////
    // reservoir
    `define RESERVOIR_IO_IN_STRUCT(DATA_WIDTH) \
    typedef struct packed { \
        logic rst_i; \
        logic [DATA_WIDTH - 1 : 0] fill_data_i; \
        logic fill_valid_i; \
        logic drain_ready_i; \
    } reservoir_io_in_t;

    `define RESERVOIR_IO_OUT_STRUCT(DATA_WIDTH) \
    typedef struct packed { \
        logic fill_ready_o; \
        logic [DATA_WIDTH - 1 : 0] drain_data_o; \
        logic drain_valid_o; \
        logic drain_burstmark_o; \
    } reservoir_io_out_t;

    ////////////////////////////////////////////////////////////////
    // reservoir no backpressure
    `define RESERVOIR_NO_BACKPRESSURE_IO_IN_STRUCT(DATA_WIDTH) \
    typedef struct packed { \
        logic rst_i; \
        logic [DATA_WIDTH - 1 : 0] fill_data_i; \
        logic fill_valid_i; \
        logic drain_ready_i; \
    } reservoir_no_backpressure_io_in_t;

    `define RESERVOIR_NO_BACKPRESSURE_IO_OUT_STRUCT(DATA_WIDTH) \
    typedef struct packed { \
        logic fill_ready_o; \
        logic fill_burstready_o; \
        logic [DATA_WIDTH - 1 : 0] drain_data_o; \
        logic drain_valid_o; \
        logic drain_burstmark_o; \
    } reservoir_no_backpressure_io_out_t;

    ////////////////////////////////////////////////////////////////
    // queue push coupler
    `define QUEUE_PUSH_COUPLER_IO_IN_STRUCT(DATA_WIDTH) \
    typedef struct packed { \
        logic rst_i; \
        logic [DATA_WIDTH - 1 : 0] wr_data_i; \
        logic wr_valid_i; \
        logic full_i; \
        logic lookahead_i; \
    } queue_push_coupler_io_in_t;

    `define QUEUE_PUSH_COUPLER_IO_OUT_STRUCT(DATA_WIDTH, ADDR_WIDTH) \
    typedef struct packed { \
        logic ready_o; \
        logic burstready_o; \
        logic [DATA_WIDTH - 1 : 0] wr_data_o; \
        logic push_o; \
        logic [ADDR_WIDTH : 0] more_than_or_eq_o; \
    } queue_push_coupler_io_out_t;

    ////////////////////////////////////////////////////////////////
    // queue pop coupler
    `define QUEUE_POP_COUPLER_IO_IN_STRUCT(DATA_WIDTH) \
    typedef struct packed { \
        logic rst_i; \
        logic empty_i; \
        logic lookahead_i; \
        logic [DATA_WIDTH - 1 : 0] rd_data_i; \
        logic rd_valid_i; \
        logic ready_i; \
    } queue_pop_coupler_io_in_t;

    `define QUEUE_POP_COUPLER_IO_OUT_STRUCT(DATA_WIDTH, ADDR_WIDTH) \
    typedef struct packed { \
        logic pop_o; \
        logic [ADDR_WIDTH : 0] less_than_or_eq_o; \
        logic [DATA_WIDTH - 1 : 0] rd_data_o; \
        logic rd_valid_o; \
        logic burstvalid_o; \
    } queue_pop_coupler_io_out_t;

    ////////////////////////////////////////////////////////////////
    // queue carriage
    `define QUEUE_CARRIAGE_IO_IN_STRUCT(DATA_WIDTH) \
    typedef struct packed { \
        logic wr_rst_i; \
        logic rd_rst_i; \
        logic [DATA_WIDTH - 1 : 0] wr_data_i; \
        logic wr_valid_i; \
        logic rd_ready_i; \
    } queue_carriage_io_in_t;

    `define QUEUE_CARRIAGE_IO_OUT_STRUCT(DATA_WIDTH) \
    typedef struct packed { \
        logic wr_ready_o; \
        logic wr_burstready_o; \
        logic [DATA_WIDTH - 1 : 0] rd_data_o; \
        logic rd_valid_o; \
        logic rd_burstvalid_o; \
    } queue_carriage_io_out_t;

    ////////////////////////////////////////////////////////////////
    // queue train
    `define QUEUE_TRAIN_IO_IN_STRUCT(DATA_WIDTH) \
    typedef struct packed { \
        logic wr_rst_i; \
        logic rd_rst_i; \
        logic [DATA_WIDTH - 1 : 0] wr_data_i; \
        logic wr_valid_i; \
        logic rd_ready_i; \
    } queue_train_io_in_t;

    `define QUEUE_TRAIN_IO_OUT_STRUCT(DATA_WIDTH) \
    typedef struct packed { \
        logic wr_ready_o; \
        logic wr_burstready_o; \
        logic [DATA_WIDTH - 1 : 0] rd_data_o; \
        logic rd_valid_o; \
        logic rd_burstvalid_o; \
    } queue_train_io_out_t;

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
        logic clk_i;

        logic [SOLAR - 1 : 0][GALACTIC - 1 : 0] data_i;
        logic                [SMALL - 1 : 0]    sel_i;

        logic                [GALACTIC - 1 : 0] data_o;
    } multistage_mux_t;

    `define MULTISTAGE_MUX_IO_IN_STRUCT(DATA_WIDTH, SIZE, SELECTOR_WIDTH) \
    typedef struct packed { \
        logic [SIZE - 1 : 0][DATA_WIDTH - 1 : 0]     data_i; \
        logic               [SELECTOR_WIDTH - 1 : 0] sel_i; \
    } multistage_mux_io_in_t;

    `define MULTISTAGE_MUX_IO_OUT_STRUCT(DATA_WIDTH) \
    typedef struct packed { \
        logic [DATA_WIDTH - 1 : 0] data_o; \
    } multistage_mux_io_out_t;

    ////////////////////////////////////////////////////////////////
    // equal
    typedef struct packed {
        int DATA_WIDTH;
        int REGISTERED_IN;
        int GRADE;
    } equal_pt;

    typedef struct packed {
        logic clk_i;

        logic [SOLAR - 1 : 0] data_a_i;
        logic [SOLAR - 1 : 0] data_b_i;

        logic eq_o;
    } equal_t;

    `define EQUAL_IO_IN_STRUCT(DATA_WIDTH) \
    typedef struct packed { \
        logic [DATA_WIDTH - 1 : 0] data_a_i; \
        logic [DATA_WIDTH - 1 : 0] data_b_i; \
    } equal_io_in_t;

    `define EQUAL_IO_OUT_STRUCT \
    typedef struct packed { \
        logic eq_o; \
    } equal_io_out_t;

    ////////////////////////////////////////////////////////////////
    // equal tree
    `define EQUAL_TREE_IO_IN_STRUCT(DATA_WIDTH) \
    typedef struct packed { \
        logic [DATA_WIDTH - 1 : 0] data_a_i; \
        logic [DATA_WIDTH - 1 : 0] data_b_i; \
    } equal_tree_io_in_t;

    `define EQUAL_TREE_IO_OUT_STRUCT \
    typedef struct packed { \
        logic eq_o; \
    } equal_tree_io_out_t;

    ////////////////////////////////////////////////////////////////
    // reduction tree
    typedef struct packed {
        int DATA_WIDTH;
        int GATE;
        int REGISTERED_IN;
        int LUTX;
        int GRADE;
    } reduction_tree_pt;

    typedef struct packed {
        logic clk_i;

        logic [SOLAR - 1 : 0] data_i;

        logic reduced_o;
    } reduction_tree_t;

    `define REDUCTION_TREE_IO_IN_STRUCT(DATA_WIDTH) \
    typedef struct packed { \
        logic [DATA_WIDTH - 1 : 0] data_i; \
    } reduction_tree_io_in_t;

    `define REDUCTION_TREE_IO_OUT_STRUCT \
    typedef struct packed { \
        logic reduced_o; \
    } reduction_tree_io_out_t;

    ////////////////////////////////////////////////////////////////
    // aligner
    typedef struct packed {
        int DATA_WIDTH;
        int SIZE;
        int REGISTERED_IN;

        // start symbol fanout
        int START_SYMBOL_FANOUT_FACTOR;
        int REGISTERED_IN_START_SYMBOL;

        // REGISTERED_IN respective
        int REGISTERED_IN_EQUAL;
        int REGISTERED_IN_PRIORITY_ENCODER;
        int REGISTERED_IN_REDUCTION_TREE;
        int REGISTERED_IN_MULTISTAGE_MUX;

        // LUTX respective
        int LUTX_EQUAL;
        int LUTX_PRIORITY_ENCODER;
        int LUTX_REDUCTION_TREE;
        int LUTX_MULTISTAGE_MUX;

        // GRADE respective
        int GRADE_EQUAL;
        int GRADE_PRIORITY_ENCODER;
        int GRADE_REDUCTION_TREE;
        int GRADE_MULTISTAGE_MUX;
    } aligner_pt;

    typedef struct packed {
        logic clk_i;

        logic [LARGE - 1 : 0][PLANETARY - 1 : 0] data_i;
        logic                [PLANETARY - 1 : 0] start_symbol_i;

        logic [LARGE - 1 : 0][PLANETARY - 1 : 0] aligned_o;
        logic                                    matched_o;
    } aligner_t;

    `define ALIGNER_IO_IN_STRUCT(DATA_WIDTH, SIZE) \
    typedef struct packed { \
        logic [SIZE - 1 : 0][DATA_WIDTH - 1 : 0] data_i; \
        logic               [DATA_WIDTH - 1 : 0] start_symbol_i; \
    } aligner_io_in_t;

    `define ALIGNER_IO_OUT_STRUCT(DATA_WIDTH, SIZE, SELECTOR_WIDTH) \
    typedef struct packed { \
        logic [SIZE - 1 : 0][DATA_WIDTH - 1 : 0] aligned_o; \
        logic                                    matched_o; \
        logic [SELECTOR_WIDTH - 1 : 0]            selector_o; \
    } aligner_io_out_t;

    ////////////////////////////////////////////////////////////////
    // packer
    `define PACKER_IO_IN_STRUCT(DATA_WIDTH, INGRESS_SIZE) \
    typedef struct packed { \
        logic [INGRESS_SIZE - 1 : 0][DATA_WIDTH - 1 : 0] unpacked_i; \
        logic                                               sync_i; \
    } packer_io_in_t;

    `define PACKER_IO_OUT_STRUCT(DATA_WIDTH, EGRESS_SIZE) \
    typedef struct packed { \
        logic [EGRESS_SIZE - 1 : 0][DATA_WIDTH - 1 : 0] packed_o; \
    } packer_io_out_t;

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
        if(FANOUT_SIZE == 1) return 1;
        return clog_base(FANOUT_FACTOR, FANOUT_SIZE);
    endfunction

    function automatic int multistage_fanout_FINAL_FANOUT_SIZE(int FANOUT_FACTOR, int STAGES);
        return (FANOUT_FACTOR ** STAGES);
    endfunction

    function automatic int multistage_fanout_LATENCY(int REGISTERED_IN, int STAGES);
        int latency = 0;
        if(REGISTERED_IN == 1) latency++;
        latency = latency + STAGES - 1;
        return latency;
    endfunction

    ////////////////////////////////////////////////////////////////
    // queue
    function automatic int queue_DATA_DEPTH(int ADDR_WIDTH);
        return (2 ** ADDR_WIDTH);
    endfunction

    function automatic int queue_READ_LATENCY(int CONFLICT_PROOF, int REGISTERED_IN, int REGISTERED_IN_BRAM, int REGISTERED_OUT_BRAM);
        int latency = bram_dual_port_simple_READ_LATENCY(REGISTERED_IN_BRAM, REGISTERED_OUT_BRAM);
        if(CONFLICT_PROOF == 1) latency++;
        if(REGISTERED_IN == 1)  latency++;
        return latency;
    endfunction

    function automatic int queue_WRITE_LATENCY(int CONFLICT_PROOF, int REGISTERED_IN, int REGISTERED_IN_BRAM);
        int latency = bram_dual_port_simple_WRITE_LATENCY(REGISTERED_IN_BRAM);
        if(CONFLICT_PROOF == 1) latency++;
        if(REGISTERED_IN == 1)  latency++;
        return latency;
    endfunction

    ////////////////////////////////////////////////////////////////
    // alternate_base_fp_adder
    function automatic int alternate_base_fp_adder_BASE_WIDTH(int BASE);
        return $clog2(BASE);
    endfunction

    function automatic int alternate_base_fp_adder_ALIGN_CHOICES(int BASE_WIDTH, int MANTISSA_WIDTH);
        int total_width, choices, pointer;
        // mantissa, guard bits (is base_width), round bit.
        total_width = MANTISSA_WIDTH + BASE_WIDTH + 1;

        choices = 0;
        pointer = total_width - 1;
        while(pointer >= 0) begin
            choices++;
            pointer = pointer - BASE_WIDTH;
        end
        choices++; // completely out of bounds is a choice.

        return choices;
  
    endfunction

    function automatic int alternate_base_fp_adder_EXPONENT_SELECTOR_WIDTH(int ALIGN_CHOICES);
        return $clog2(ALIGN_CHOICES);
    endfunction

    function automatic int [PLANETARY - 1 : 0][1:0] alternate_base_fp_adder_STICKY_OR_INDICES(
        int BASE_WIDTH, 
        int MANTISSA_WIDTH, 
        int ALIGN_CHOICES, 
        int LUTX, 
        int GRADE);

        int total_width, index, mantissa_lsb_index, latency, group_size, stages;

        // [index, latency]
        int [PLANETARY - 1 : 0][1:0] sticky_or_indices;
        
        for(int i = 0; i < PLANETARY; i++) begin
            for(int k = 0; k < 2; k++) begin
                sticky_or_indices[i][k] = 0;
            end
        end

        // mantissa, guard bits (is base_width), round bit.
        total_width = MANTISSA_WIDTH + BASE_WIDTH + 1;

        // the guard bits and round bit consume what otherwise would have been sticky
        mantissa_lsb_index = BASE_WIDTH + 1;
        index = 0;
        group_size = reduction_tree_GROUP_SIZE(LUTX, GRADE);

        for(int c = 0; c < ALIGN_CHOICES; c++) begin
            if(index < mantissa_lsb_index) begin
                sticky_or_indices[c][0] = -1;
                sticky_or_indices[c][1] = 0;
            end else begin
                stages  = reduction_tree_STAGES(group_size, index - mantissa_lsb_index + 1);
                latency = reduction_tree_LATENCY(0, stages);
                sticky_or_indices[c][0] = min(index, total_width - 1);
                sticky_or_indices[c][1] = latency;
            end
        end

        return sticky_or_indices;
    endfunction

    function automatic int alternate_base_fp_adder_STICKY_MAX_LATENCY(
        int ALIGN_CHOICES,
        int [PLANETARY - 1 : 0][1:0] STICKY_OR_INDICES
    );
        int max_latency = 0;
        for(int c = 0; c < ALIGN_CHOICES; c++) begin
            max_latency = max(max_latency, STICKY_OR_INDICES[c][1]);
        end

        return max_latency;
    endfunction

    function automatic int alternate_base_fp_adder_EXPONENT_LATENCY(int REGISTERED_EXPONENT_MUX);
        if(REGISTERED_EXPONENT_MUX == 1) return 1;
        return 0;
    endfunction

    function automatic int alternate_base_fp_adder_BALANCED_MAX_LATENCY(int STICKY_MAX_LATENCY, int EXPONENT_LATENCY);
        return max(EXPONENT_LATENCY, STICKY_MAX_LATENCY);
    endfunction

    function automatic int alternate_base_fp_adder_NORMALIZE_CHOICES(int BASE_WIDTH, int MANTISSA_WIDTH);
        int total_width, choices, pointer;
        // carry bit, mantissa, guard bits (is base_width)
        total_width = 1 + MANTISSA_WIDTH + BASE_WIDTH;

        choices = 0;
        pointer = total_width - 1;

        // carry bit
        choices++; // start with carry choice
        point--;

        while(pointer >= 0) begin
            choices++;
            pointer = pointer - BASE_WIDTH;
        end
        //c[x x][x x x x][x x x x][x x x x][g g g g]
        //. .        .        .        .        .
        //1 2        3        4        5        6
        //  0        1        2        3        4
        return choices;
    endfunction

    function automatic int alternate_base_fp_adder_NORMALIZE_OR_MAX_LATENCY(
        int LUTX, 
        int GRADE, 
        int MANTISSA_WIDTH,
        int BASE_WIDTH, 
        int NORMALIZE_CHOICES
    );
        int group_size, stages, data_width, latency;
        data_width = min(MANTISSSA_WIDTH, BASE_WIDTH);
        group_size = reduction_tree_GROUP_SIZE(LUTX, GRADE);
        stages     = reduction_tree_STAGES(group_size, data_width);
        latency    = reduction_tree_LATENCY(0, stages);

        return latency;
    endfunction

    function automatic int_t [PLANETARY - 1 : 0][1 : 0] alternate_base_fp_adder_NORMALIZE_OR_INDICES(
        int BASE_WIDTH, 
        int MANTISSA_WIDTH, 
        int NORMALIZE_CHOICES, 
        int LUTX, 
        int GRADE
    );
        int total_width, left_index, right_index, latency, group_size, stages;

        // [left_idx, right_idx, latency]
        int [PLANETARY - 1 : 0][2:0] normalize_or_indices;
        
        for(int i = 0; i < PLANETARY; i++) begin
            for(int k = 0; k < 3; k++) begin
                normalize_or_indices[i][k] = 0;
            end
        end

        // carry bit, mantissa, guard bits (is base_width), round bit, sticky bit
        total_width = 1 + MANTISSA_WIDTH + BASE_WIDTH + 1 + 1;
        guard_lsb_index = 2;
        
        group_size = reduction_tree_GROUP_SIZE(LUTX, GRADE);

        // carry bit first
        left_index = total_width - 1;
        right_index = left_index - 1;
        normalize_or_indices[0] = left_index;
        normalize_or_indices[1] = right_index;
        stages  = reduction_tree_STAGES(group_size, left_index - right_index + 1);
        latency = reduction_tree_LATENCY(0, stages);
        normalize_or_indices[2] = latency;


        for(int c = 1; c < NORMALIZE_CHOICES; c++) begin
            left_index = total_width - 1;
            right_index = max((left_index - 1), guard_lsb_index);
            normalize_or_indices[0] = left_index;
            normalize_or_indices[1] = right_index;
            stages  = reduction_tree_STAGES(group_size, left_index - right_index + 1);
            latency = reduction_tree_LATENCY(0, stages);
            normalize_or_indices[2] = latency;
        end

        return normalize_or_indices;
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
                max_tree_map[r][c] = 0;
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
        if(INPUT_DATA_WIDTH == 1) return 1;
        return $clog2(INPUT_DATA_WIDTH);
    endfunction

    ////////////////////////////////////////////////////////////////
    // multistage mux
    function automatic int multistage_mux_SELECTOR_WIDTH(int SIZE);
        if(SIZE == 1) return 1;
        return $clog2(SIZE);
    endfunction

    function automatic int multistage_mux_GROUP_SELECTOR_WIDTH(int LUTX, int GRADE);
        int width_mux_ability, graded_mux_ability;

        width_mux_ability = mux_ability(LUTX);
        graded_mux_ability = width_mux_ability * GRADE;

        return graded_mux_ability;
    endfunction

    function automatic int multistage_mux_GROUP_SIZE(int GROUP_SELECTOR_WIDTH);
        return 2 ** GROUP_SELECTOR_WIDTH;
    endfunction

    function automatic int multistage_mux_STAGES(int GROUP_SIZE, int SIZE);
        if(SIZE == 1) return 1;
        return clog_base(GROUP_SIZE, SIZE);
    endfunction

    function automatic int_t [SMALL - 1 : 0][SOLAR - 1 : 0] multistage_mux_MUX_TREE_MAP(int STAGES, int GROUP_SIZE, int SIZE);
        int_t [SMALL - 1 : 0][SOLAR - 1 : 0] mux_tree_map;
        int counter;
        
        // initialize all values to 0
        for(int r = 0; r < SMALL; r++) begin
            for(int c = 0; c < SOLAR; c++) begin
                mux_tree_map[r][c] = 0;
            end
        end

        // set 0th row to 1s for each input 
        for(int i = 0; i < SIZE; i++) begin
            mux_tree_map[0][i] = 1;
        end

        // *we set the lowest index for each group the number of actual inputs available
        // and is used to deal with partial groups

        for(int group = 0; group < SIZE; group += GROUP_SIZE) begin
            counter = 0;
            for(int g = 0; g < GROUP_SIZE; g++) begin
                if(mux_tree_map[0][group + g] != 0) counter++;
            end
            mux_tree_map[0][group] = counter;
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
                    if(mux_tree_map[row][group + g] != 0) counter++;
                end
                mux_tree_map[row][group] = counter;
            end
        end

        return mux_tree_map;
    endfunction

    function automatic int multistage_mux_LATENCY(int REGISTERED_IN, int STAGES);
        int latency = 0;
        if(REGISTERED_IN == 1) latency++;
        latency = latency + STAGES - 1;
        return latency;
    endfunction

    ////////////////////////////////////////////////////////////////
    // equal
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

    ////////////////////////////////////////////////////////////////
    // reduction tree
    function automatic int reduction_tree_GROUP_SIZE(int LUTX, int GRADE);
        return LUTX ** GRADE;
    endfunction

    function automatic int reduction_tree_STAGES(int GROUP_SIZE, int DATA_WIDTH);
        if(DATA_WIDTH == 1) return 1;
        return clog_base(GROUP_SIZE, DATA_WIDTH);
    endfunction

    function automatic int reduction_tree_LATENCY(int REGISTERED_IN, int STAGES);
        int latency = 0;
        if(REGISTERED_IN == 1) latency++;
        latency = latency + STAGES - 1;
        return latency;
    endfunction

    ////////////////////////////////////////////////////////////////
    // aligner
    function automatic int aligner_SIZE_COMBINED(int SIZE);
        int cs = SIZE * 2;
        return cs;
    endfunction

    function automatic int aligner_FLATTEN_WIDTH(int DATA_WIDTH, int SIZE);
        int f = DATA_WIDTH * SIZE;
        return f;
    endfunction

    function automatic int aligner_ADJUST_PRIORITY_ENCODER_LATENCY(int PRIORITY_ENCODER_LATENCY, int REDUCTION_TREE_LATENCY);
        return max(0, REDUCTION_TREE_LATENCY - PRIORITY_ENCODER_LATENCY);
    endfunction

    function automatic int aligner_ADJUST_REDUCTION_TREE_LATENCY(int PRIORITY_ENCODER_LATENCY, int REDUCTION_TREE_LATENCY);
        return max(0, PRIORITY_ENCODER_LATENCY - REDUCTION_TREE_LATENCY);
    endfunction

    function automatic int aligner_PARTIAL_LATENCY(
        int START_SYMBOL_LATENCY,
        int EQUAL_LATENCY,
        int PRIORITY_ENCODER_LATENCY,
        int REDUCTION_TREE_LATENCY);

        int latency = 0;
        latency += (START_SYMBOL_LATENCY + EQUAL_LATENCY + max(PRIORITY_ENCODER_LATENCY, REDUCTION_TREE_LATENCY));
        latency += 1;
        return latency;
    endfunction

    function automatic int aligner_LATENCY(int REGISTERED_IN, int PARTIAL_LATENCY, int MULTISTAGE_MUX_LATENCY);
        int latency = PARTIAL_LATENCY;
        if(REGISTERED_IN == 1) latency++;
        latency += MULTISTAGE_MUX_LATENCY;
        return latency;
    endfunction

    function automatic int aligner_SELECTED_SIZE(int SIZE, START_INDEX);
        int s;
        s = SIZE - START_INDEX;
        return s;
    endfunction

    ////////////////////////////////////////////////////////////////
    // fsm strider ohe
    function automatic int fsm_strider_ohe_SYNC_IDX(int STRIDE);
        if(STRIDE == 1) return 0;
        return 1;
    endfunction

    ////////////////////////////////////////////////////////////////
    // packer
    function automatic int packer_STRIDE(int INGRESS_SIZE, int EGRESS_SIZE);
        int stride;
        stride = EGRESS_SIZE / INGRESS_SIZE;
        return stride;
    endfunction

    function automatic int packer_LATENCY(int REGISTERED_IN, int STRIDE);
        int latency;
        if(REGISTERED_IN == 1) latency++;
        latency += (STRIDE - 1);
        return latency;
    endfunction

    ////////////////////////////////////////////////////////////////
    // fsm timeout
    function automatic int fsm_timeout_COUNTER_WIDTH(int TIMEOUT);
        if (TIMEOUT == 0) return 2;
        return $clog2(TIMEOUT) + 2;
    endfunction

    ////////////////////////////////////////////////////////////////
    // reservoir
    function automatic int reservoir_ENTRIES(int WATERMARK_ENTRIES, int BACKPRESSURE_ENTRIES);
        return (WATERMARK_ENTRIES + BACKPRESSURE_ENTRIES);
    endfunction

    ////////////////////////////////////////////////////////////////
    // queue async
    function automatic int queue_async_WRITE_LATENCY();
        return 1;
    endfunction

    function automatic int queue_async_READ_LATENCY(int REGISTERED_OUT_BRAM);
        if(REGISTERED_OUT_BRAM == 1) return 2;
        return 1;
    endfunction;

    ////////////////////////////////////////////////////////////////
    // queue push coupler
    function automatic int queue_push_coupler_RESERVOIR_BACKPRESSURE_ENTRIES(int BURST_SIZE);
        return (BURST_SIZE - 1);
    endfunction

    ////////////////////////////////////////////////////////////////
    // queue pop coupler
    function automatic int queue_pop_coupler_SPOOL_UP(
        int ASYNC,
        int CONFLICT_PROOF,
        int REGISTERED_IN,
        int REGISTERED_IN_BRAM,
        int REGISTERED_OUT_BRAM
    );
        // +1 to assert pop
        // + read latency to fetch data
        if(ASYNC == 1) return (1 + queue_async_READ_LATENCY(REGISTERED_OUT_BRAM));
        return (1 + queue_READ_LATENCY(CONFLICT_PROOF, REGISTERED_IN, REGISTERED_IN_BRAM, REGISTERED_OUT_BRAM));
    endfunction

    function automatic int queue_pop_coupler_SPOOL_DOWN();
        // +1 to deassert pop
        return 1;
    endfunction

    function automatic int queue_pop_coupler_RESERVOIR_WATERMARK_ENTRIES(int SPOOL_UP, int BURSTMARK);
        // following reservoir formula : (spool up cycles + 1 + BURSTMARK)
        return (SPOOL_UP + 1 + BURSTMARK);
    endfunction

    function automatic int queue_pop_coupler_RESERVOIR_BACKPRESSURE_ENTRIES(int SPOOL_UP, int SPOOL_DOWN);
        // following reservoir formula: (spool up cycles + spool down cycles - 1)
        return (SPOOL_UP + SPOOL_DOWN - 1);
    endfunction

    ////////////////////////////////////////////////////////////////
    // queue carriage
    function automatic int queue_carriage_READ_LATENCY(
        int ASYNC,
        int CONFLICT_PROOF,
        int REGISTERED_IN,
        int REGISTERED_IN_BRAM,
        int REGISTERED_OUT_BRAM
    );
        if(ASYNC == 1) return queue_async_READ_LATENCY(REGISTERED_OUT_BRAM);
        return queue_READ_LATENCY(CONFLICT_PROOF, REGISTERED_IN, REGISTERED_IN_BRAM, REGISTERED_OUT_BRAM);
    endfunction

    ////////////////////////////////////////////////////////////////
    // equal tree
    function automatic int equal_tree_LUTX_HALF_GRADED(int LUTX, int GRADE);
        int lutx_nearest_floor_even;
        lutx_nearest_floor_even = (LUTX / 2) * 2;      // turn into nearest floor even number
        return (lutx_nearest_floor_even ** GRADE) / 2; // even number divide by 2 no issue.
    endfunction

    function automatic int equal_tree_PADDED_WIDTH(int DATA_WIDTH, int LUTX_HALF_GRADED);
        int not_divisible, a;
        not_divisible = (DATA_WIDTH % LUTX_HALF_GRADED) != 0 ? 1 : 0;
        a = (DATA_WIDTH / LUTX_HALF_GRADED) * LUTX_HALF_GRADED;
        return (a + (not_divisible * LUTX_HALF_GRADED));
    endfunction

    function automatic int equal_tree_GROUPS(int PADDED_WIDTH, int LUTX_HALF_GRADED);
        return (PADDED_WIDTH / LUTX_HALF_GRADED);
    endfunction

    function automatic int equal_tree_LATENCY(int REGISTERED_IN, int GROUPS, int REDUCTION_TREE_LATENCY);
        int latency = 0;
        if(REGISTERED_IN == 1) latency++;
        if(GROUPS > 1) begin
            latency += REDUCTION_TREE_LATENCY;
        end 
        return latency;
    endfunction

endpackage
