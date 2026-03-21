package constant_functions_pkg;
    import shared_upper_bound_packed_dimensions::*;
    ////////////////////////////////////////////////////////////////
    //          Max-bounding localparams for packed arrays        //
    //////////////////////////////////////////////////////////////// 



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


endpackage
