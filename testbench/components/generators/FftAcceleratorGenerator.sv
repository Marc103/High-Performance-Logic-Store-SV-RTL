import constant_functions_pkg::*;
class FftAcceleratorGenerator #(type T);
    typedef T::complex_t complex_t;
    `FFT_ACCELERATOR_IO_IN_STRUCT(T::SAMPLES_ADDR_WIDTH)
    TriggerableQueueBroadcaster #(T) out_broadcaster;
    function new(TriggerableQueueBroadcaster #(T) out_broadcaster);
        this.out_broadcaster=out_broadcaster;
    endfunction
    task automatic read_memory(string filename, int depth, ref complex_t words[]);
        int fd, code, digit, n;
        string token, discarded;
        logic [T::COMPLEX_DATA_WIDTH+3:0] value;
        fd=$fopen(filename,"r");
        if(!fd) $fatal(1,"Cannot open memory file %s",filename);
        words=new[depth]; n=0;
        while($fscanf(fd,"%s",token)==1) begin
            if(token.len()>=2 && token.substr(0,1)=="//") begin code=$fgets(discarded,fd); continue; end
            if(n>=depth) $fatal(1,"%s contains more than %0d words",filename,depth);
            if(token.len()>(T::COMPLEX_DATA_WIDTH+3)/4) $fatal(1,"Overwide word in %s at index %0d",filename,n);
            value='0;
            for(int i=0;i<token.len();i++) begin
                if(token[i]>=8'h30 && token[i]<=8'h39) digit=int'(token[i])-48;
                else if(token[i]>=8'h61 && token[i]<=8'h66) digit=int'(token[i])-87;
                else if(token[i]>=8'h41 && token[i]<=8'h46) digit=int'(token[i])-55;
                else begin $fatal(1,"Invalid hex word %s in %s at index %0d",token,filename,n); digit=0; end
                value=(value<<4)|digit;
            end
            if((value>>T::COMPLEX_DATA_WIDTH)!=0) $fatal(1,"Word exceeds the configured complex width in %s",filename);
            words[n]=T::COMPLEX_DATA_WIDTH'(value); n++;
        end
        $fclose(fd);
        if(n!=depth) $fatal(1,"%s must contain exactly %0d words; found %0d",filename,depth,n);
    endtask
    task automatic run();
        T obj;
        complex_t source_samples[],source_twiddles[];
        fft_accelerator_io_in_t controls;
        string test_dir,result_dir;
        int logical_index,file_index;
        obj=new(); obj.points=T::FFT_POINTS; obj.count=T::FFT_COUNT;
        obj.samples_file=T::SAMPLES_FILE; obj.twiddles_file=T::TWIDDLES_FILE; obj.result_file=T::RESULT_FILE;
        test_dir="../test_files"; result_dir="../result_files";
        void'($value$plusargs("TEST_FILES_DIR=%s",test_dir)); void'($value$plusargs("RESULT_DIR=%s",result_dir));
        void'($value$plusargs("SAMPLES_FILE=%s",obj.samples_file)); void'($value$plusargs("TWIDDLES_FILE=%s",obj.twiddles_file));
        void'($value$plusargs("RESULT_FILE=%s",obj.result_file)); void'($value$plusargs("FFT_POINTS=%d",obj.points));
        void'($value$plusargs("FFT_COUNT=%d",obj.count)); void'($value$plusargs("SAMPLE_ORDER_POINTS=%d",obj.sample_order_points));
        void'($value$plusargs("TWIDDLE_POINTS=%d",obj.twiddle_points)); void'($value$plusargs("SAMPLE_RATE_HZ=%f",obj.sample_rate_hz));
        if(!T::is_power_of_two(obj.points) || obj.points<2 || obj.points>32768 ||
           obj.points>2**T::SAMPLES_ADDR_WIDTH || obj.points>2**(T::TWIDDLES_ADDR_WIDTH+1) ||
           obj.count<1 || obj.count>min(32768,2**T::SAMPLES_ADDR_WIDTH)/obj.points)
            $fatal(1,"Invalid FFT size/count for the 32K sample and 16K twiddle capacities");
        if(!T::is_power_of_two(obj.sample_order_points) || obj.sample_order_points>32768 ||
           !T::is_power_of_two(obj.twiddle_points) || obj.twiddle_points<obj.points || obj.twiddle_points>32768)
            $fatal(1,"Invalid source-file ordering/twiddle size");
        // Exercise the configured interval, including the minimum II=4.
        // The exact model/scoreboard must expose any in-place dependency failure;
        // WRITE_COMMIT_LATENCY is a sufficient bound, not a minimum legal II.
        obj.samples_file=T::resolve_path(test_dir,obj.samples_file);
        obj.twiddles_file=T::resolve_path(test_dir,obj.twiddles_file);
        obj.result_file=T::resolve_path(result_dir,obj.result_file);
        read_memory(obj.samples_file,32768,source_samples);
        read_memory(obj.twiddles_file,16384,source_twiddles);
        obj.initial_samples=new[32768]; obj.twiddles=new[16384];
        for(int i=0;i<32768;i++) begin
            logical_index=(i/obj.points)*obj.points+T::reverse_bits(i%obj.points,$clog2(obj.points));
            file_index=(logical_index/obj.sample_order_points)*obj.sample_order_points+
                       T::reverse_bits(logical_index%obj.sample_order_points,$clog2(obj.sample_order_points));
            obj.initial_samples[i]=source_samples[file_index];
        end
        foreach(obj.twiddles[i]) obj.twiddles[i]='0;
        for(int k=0;k<obj.points/2;k++) obj.twiddles[k]=source_twiddles[k*(obj.twiddle_points/obj.points)];
        controls.rst_i=0; controls.go_i=1;
        controls.fft_point_size_i=(T::SAMPLES_ADDR_WIDTH+1)'(obj.points);
        controls.fft_whole_iterations_i=T::SAMPLES_ADDR_WIDTH'(obj.count);
        obj.fft_accelerator_io_in_q.push_back(controls); obj.idle.push_back(0);
        obj.end_last_sequence=1;
        out_broadcaster.push(obj);
    endtask
endclass
