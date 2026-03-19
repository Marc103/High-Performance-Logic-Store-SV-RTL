package constant_functions_pkg;
    ////////////////////////////////////////////////////////////////
    //          Max-bounding localparams for packed arrays        //
    //////////////////////////////////////////////////////////////// 



    ////////////////////////////////////////////////////////////////
    //          Non-module specific utility functions             //
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
    //           Module specific utility functions                //
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




endpackage