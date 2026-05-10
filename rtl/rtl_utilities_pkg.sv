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
        QUEUE
    } module_id_e;
    

    ////////////////////////////////////////////////////////////////
    //          Non-module specific constant functions            //
    //////////////////////////////////////////////////////////////// 


    function automatic int clog_base(int base, int value);
        int exponent = 0;
        int acc = 1;

        // Some sanity checks to prevent forever loop
        if(base <= 0)  $fatal("base is zero or negative: %d", base);
        if(value <= 0) $fatal("value is zero or negative: %d", value);

        while(acc < value) begin
            acc = acc * base;
            exponent++;
        end

        return exponent;
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
        logic                    valid_i;

        logic [SOLAR - 1 : 0][GALACTIC - 1 : 0] data_o;
        logic [SOLAR - 1 : 0]                   valid_o;
    } multistage_fanout_t;

    ////////////////////////////////////////////////////////////////
    //           Module specific constant functions               //
    ////////////////////////////////////////////////////////////////


    ////////////////////////////////////////////////////////////////
    // bram_single_port
    function automatic int bram_single_port_DATA_DEPTH(int ADDR_WIDTH);
        return (2 ** ADDR_WIDTH);
    endfunction

    function automatic int bram_single_port_LATENCY(int REGISTERED_IN);
        int latency = 1;
        if(REGISTERED_IN == 1) latency = 2;
        return latency;
    endfunction

    ////////////////////////////////////////////////////////////////
    // bram_dual_port_simple
    function automatic int bram_dual_port_simple_DATA_DEPTH(int ADDR_WIDTH);
        return bram_single_port_DATA_DEPTH(ADDR_WIDTH);
    endfunction

    function automatic int bram_dual_port_simple_LATENCY(int REGISTERED_IN);
        return bram_single_port_LATENCY(REGISTERED_IN);
    endfunction

    ////////////////////////////////////////////////////////////////
    // multistage_fanout
    function automatic int multistage_fanout_STAGES(int FANOUT_FACTOR, int FANOUT_SIZE);
        return clog_base(FANOUT_FACTOR, FANOUT_SIZE);
    endfunction

    function automatic int multistage_fanout_PRE_FANOUT_SIZE(int FANOUT_FACTOR, int STAGES);
        return (FANOUT_FACTOR ** (STAGES - 1));
    endfunction

    function automatic int multistage_fanout_FINAL_FANOUT_SIZE(int FANOUT_FACTOR, int STAGES);
        return (FANOUT_FACTOR ** STAGES);
    endfunction

    function automatic int multistage_fanout_LATENCY(int IMMEDIATE_START_FANOUT, int STAGES);
        if(IMMEDIATE_START_FANOUT == 1) begin
            return (STAGES - 1);
        end else begin
            return STAGES;
        end
    endfunction

    ////////////////////////////////////////////////////////////////
    // queue
    function automatic int queue_DATA_DEPTH(int ADDR_WIDTH);
        return bram_dual_port_simple_DATA_DEPTH(ADDR_WIDTH);
    endfunction

    function automatic int queue_LATENCY(int REGISTERED_IN, int REGISTERED_IN_BRAM, int READ_THEN_WRITE);
        int a = 0;
        if(REGISTERED_IN)    a += 1;
        if(READ_THEN_WRITE)  a += 1;
        return (a + bram_dual_port_simple_LATENCY(REGISTERED_IN_BRAM));

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

endpackage
