package constant_functions_pkg;
    function automatic int fanout_stages(int fanout_size, int fanout_factor);
        int size = fanout_factor;
        int stages = 0;

        // Some sanity checks to prevent forever loop
        if(fanout_factor < 0) $fatal("Fanout factor is zero or negative: %d", fanout_factor);
        if(fanout_size < 0)   $fatal("Fanout size is zero or negative: %d", fanout_size);

        while(size < fanout_size) begin
            size = size * fanout_factor;
            stages++;
        end

        return stages;
    endfunction
endpackage