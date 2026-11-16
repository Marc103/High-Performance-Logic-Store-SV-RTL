import constant_functions_pkg::*;
class FftAcceleratorModel #(type T);
    typedef T::word_t word_t;
    typedef T::adder_io_t adder_io_t;
    typedef T::multiplier_io_t multiplier_io_t;
    typedef T::write_event_t write_event_t;
    typedef T::read_event_t read_event_t;
    `ALTERNATE_BASE_FP_ADDER_IO_IN_STRUCT(T::DATA_WIDTH)
    `ALTERNATE_BASE_FP_MULTIPLIER_IO_IN_STRUCT(T::DATA_WIDTH)
    `FFT_ACCELERATOR_IO_OUT_STRUCT
    TriggerableQueue #(T) in_queue;
    TriggerableQueueBroadcaster #(T) out_broadcaster;
    AlternateBaseFpAdderModel #(adder_io_t) adder;
    AlternateBaseFpMultiplierModel #(multiplier_io_t) multiplier;
    function new(TriggerableQueue #(T) in_queue, TriggerableQueueBroadcaster #(T) out_broadcaster);
        this.in_queue=in_queue; this.out_broadcaster=out_broadcaster;
        adder=new(null,null); multiplier=new(null,null);
    endfunction
    function automatic word_t negate(word_t x);
        x[T::DATA_WIDTH-1]=~x[T::DATA_WIDTH-1]; return x;
    endfunction
    function automatic word_t add_words(word_t x,y);
        alternate_base_fp_adder_io_in_t t;
        if($isunknown({x,y}) || (!adder.finite_operand(x) && !adder.special_operand(x)) ||
           (!adder.finite_operand(y) && !adder.special_operand(y))) $fatal(1,"Invalid ABFP adder operand in FFT model");
        t={x,y}; return adder.add_values(t);
    endfunction
    function automatic word_t multiply_words(word_t x,y);
        alternate_base_fp_multiplier_io_in_t t;
        if($isunknown({x,y}) || !multiplier.valid_operand(x) || !multiplier.valid_operand(y))
            $fatal(1,"Invalid ABFP multiplier operand in FFT model");
        t={x,y}; return multiplier.multiply_values(t);
    endfunction
    task automatic transform(T obj);
        word_t ar,ai,br,bi,wr,wi,tr,ti,y0r,y0i,y1r,y1i;
        write_event_t event_value;
        read_event_t request;
        fft_accelerator_io_out_t status;
        int a,b,k;
        longint unsigned pair_index, read_clock;
        obj.final_samples=obj.initial_samples;
        pair_index=0;
        // Independent mathematical DIT traversal; every arithmetic operation uses
        // the existing exact ABFP models, including reserved encodings and RNE.
        for(int size=2;size<=obj.points;size*=2)
            for(int whole=0;whole<obj.count;whole++)
                for(int base_addr=0;base_addr<obj.points;base_addr+=size)
                    for(int p=0;p<size/2;p++) begin
                        a=whole*obj.points+base_addr+p; b=a+size/2; k=p*(obj.points/size);
                        read_clock=2+pair_index*T::II_CYCLES;
                        request.cycle=read_clock; request.address=T::SAMPLES_ADDR_WIDTH'(b);
                        request.twiddle_address=T::TWIDDLES_ADDR_WIDTH'(k); request.is_b=1; obj.reads.push_back(request);
                        request.cycle=read_clock+1; request.address=T::SAMPLES_ADDR_WIDTH'(a); request.is_b=0; obj.reads.push_back(request);
                        {ar,ai}=obj.final_samples[a]; {br,bi}=obj.final_samples[b]; {wr,wi}=obj.twiddles[k];
                        tr=add_words(multiply_words(wr,br),negate(multiply_words(wi,bi)));
                        ti=add_words(multiply_words(wr,bi),multiply_words(wi,br));
                        y0r=add_words(tr,ar); y1r=add_words(negate(tr),ar);
                        y0i=add_words(ti,ai); y1i=add_words(negate(ti),ai);
                        obj.final_samples[a]={y0r,y0i}; obj.final_samples[b]={y1r,y1i};
                        event_value.cycle=read_clock+T::LATENCY; event_value.address=T::SAMPLES_ADDR_WIDTH'(b);
                        event_value.data={y1r,y1i}; obj.writes.push_back(event_value);
                        event_value.cycle+=T::WRITE_LATENCY; obj.commits.push_back(event_value);
                        event_value.cycle=read_clock+T::LATENCY+1; event_value.address=T::SAMPLES_ADDR_WIDTH'(a);
                        event_value.data={y0r,y0i}; obj.writes.push_back(event_value);
                        event_value.cycle+=T::WRITE_LATENCY; obj.commits.push_back(event_value);
                        pair_index++;
                    end
        obj.elapsed_cycles=2+(pair_index-1)*T::II_CYCLES+max(T::II_CYCLES-1,T::WRITE_COMMIT_LATENCY);
        status='{busy_o:0,fft_done_o:1}; obj.fft_accelerator_io_out_q.push_back(status);
        obj.error_state.push_back(0);
        $display("Golden FFT ready: N=%0d count=%0d butterflies=%0d",obj.points,obj.count,pair_index);
    endtask
    task automatic run();
        T obj;
        forever begin in_queue.pop(obj); transform(obj); out_broadcaster.push(obj); end
    endtask
endclass
