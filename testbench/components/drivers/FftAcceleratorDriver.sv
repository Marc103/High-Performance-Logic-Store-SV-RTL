import constant_functions_pkg::*;
class FftAcceleratorDriver #(type T, type I);
    TriggerableQueue #(T) in_queue;
    TriggerableQueue #(T) monitor_metadata;
    TriggerableQueue #(T) load_requests, load_done;
    I inf;
    function new(TriggerableQueue #(T) in_queue, I inf, TriggerableQueue #(T) monitor_metadata,
                 TriggerableQueue #(T) load_requests, TriggerableQueue #(T) load_done);
        this.in_queue=in_queue; this.inf=inf; this.monitor_metadata=monitor_metadata;
        this.load_requests=load_requests; this.load_done=load_done;
    endfunction
    task automatic drive(T obj);
        longint unsigned timeout_cycles, waited;
        T loaded;
        @(negedge inf.clk_i); #1;
        if(inf.busy_o || inf.samples_wr_en_o) $fatal(1,"Cannot load memories while accelerator is active");
        inf.loading=1; inf.rst_i=1; inf.go_i=0;
        inf.fft_point_size_i=(T::SAMPLES_ADDR_WIDTH+1)'(obj.points);
        inf.fft_whole_iterations_i=T::SAMPLES_ADDR_WIDTH'(obj.count);
        repeat(T::RESET_HOLD_CYCLES) @(negedge inf.clk_i);
        #1;
        load_requests.push(obj); load_done.pop(loaded);
        if(loaded!=obj) $fatal(1,"Memory load acknowledgment mismatch");
        inf.rst_i=0;
        repeat(T::RESET_PIPELINE_DEPTH+3) @(negedge inf.clk_i);
        #1;
        // Keep variable-length filenames in class metadata rather than the
        // virtual interface, whose string triggers are unsupported by Verilator.
        monitor_metadata.push(obj);
        inf.loading=0; inf.idle=0; inf.start_sequence=1; inf.end_sequence=0;
        inf.end_last_sequence=obj.end_last_sequence;
        inf.go_i=1;
        @(negedge inf.clk_i); #1;
        inf.go_i=0; inf.start_sequence=0;
        timeout_cycles=longint'(obj.points/2)*obj.count*$clog2(obj.points)*T::II_CYCLES+
                       T::WRITE_COMMIT_LATENCY+T::RESET_PIPELINE_DEPTH+64;
        waited=0;
        forever begin
            @(posedge inf.clk_i); #2;
            if(inf.fft_done_o) break;
            waited++;
            if(waited>timeout_cycles) $fatal(1,"Accelerator timed out after %0d clocks",waited);
        end
        inf.end_sequence=1;
        @(negedge inf.clk_i); #1;
        inf.end_sequence=0; inf.end_last_sequence=0; inf.idle=1;
    endtask
    task automatic run();
        T obj;
        forever begin in_queue.pop(obj); drive(obj); end
    endtask
endclass
