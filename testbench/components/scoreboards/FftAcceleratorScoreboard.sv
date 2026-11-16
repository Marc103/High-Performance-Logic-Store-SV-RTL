import constant_functions_pkg::*;
class FftAcceleratorScoreboard #(type T);
    TriggerableQueue #(T) in_queue_dut, in_queue_golden;
    function new(TriggerableQueue #(T) in_queue_dut, TriggerableQueue #(T) in_queue_golden);
        this.in_queue_dut=in_queue_dut; this.in_queue_golden=in_queue_golden;
    endfunction
    function automatic string json_string(string value);
        string result;
        result="";
        for(int i=0;i<value.len();i++) begin
            if(value[i]==8'h22) result={result,"\\\""};
            else if(value[i]==8'h5c) result={result,"\\\\"};
            else result={result,value.substr(i,i)};
        end
        return result;
    endfunction
    task automatic save_result(T obj, bit passed);
        int fd;
        fd=$fopen(obj.result_file,"w");
        if(!fd) $fatal(1,"Cannot create result file %s; create its parent directory first",obj.result_file);
        foreach(obj.final_samples[i]) $fdisplay(fd,"%h",obj.final_samples[i]);
        $fclose(fd);
        fd=$fopen({obj.result_file,".json"},"w");
        if(!fd) $fatal(1,"Cannot create result metadata");
        $fdisplay(fd,"{");
        $fdisplay(fd,"  \"status\": \"%s\",",passed?"passed":"failed");
        $fdisplay(fd,"  \"base\": %0d, \"exponent_width\": %0d, \"mantissa_width\": %0d,",T::BASE,T::EXPONENT_WIDTH,T::MANTISSA_WIDTH);
        $fdisplay(fd,"  \"fft_points\": %0d, \"fft_count\": %0d,",obj.points,obj.count);
        $fdisplay(fd,"  \"depth\": 32768, \"sample_order_points\": %0d, \"twiddle_points\": %0d,",obj.sample_order_points,obj.twiddle_points);
        $fdisplay(fd,"  \"sample_rate_hz\": %0.12g, \"result_order\": \"natural within each transformed block\",",obj.sample_rate_hz);
        $fdisplay(fd,"  \"samples_file\": \"%s\",",json_string(obj.samples_file));
        $fdisplay(fd,"  \"twiddles_file\": \"%s\",",json_string(obj.twiddles_file));
        $fdisplay(fd,"  \"ii_cycles\": %0d, \"read_latency\": %0d, \"write_latency\": %0d,",T::II_CYCLES,T::READ_LATENCY,T::WRITE_LATENCY);
        $fdisplay(fd,"  \"elapsed_cycles\": %0d, \"writes\": %0d, \"commits\": %0d",obj.elapsed_cycles,obj.writes.size(),obj.commits.size());
        $fdisplay(fd,"}"); $fclose(fd);
    endtask
    task automatic run();
        T actual,expected;
        int errors;
        forever begin
            in_queue_golden.pop(expected); in_queue_dut.pop(actual); errors=0;
            if(actual.points!=expected.points || actual.count!=expected.count || actual.samples_file!=expected.samples_file ||
               actual.twiddles_file!=expected.twiddles_file || actual.result_file!=expected.result_file)
                $fatal(1,"Driver/model job metadata mismatch");
            if(actual.fft_accelerator_io_in_q.size()!=1 || actual.fft_accelerator_io_in_q[0] !== expected.fft_accelerator_io_in_q[0] ||
               actual.fft_accelerator_io_out_q.size()!=1 || actual.fft_accelerator_io_out_q[0] !== expected.fft_accelerator_io_out_q[0] ||
               expected.error_state.size()!=1 || expected.error_state[0]!==0 || actual.end_last_sequence!=expected.end_last_sequence)
                $fatal(1,"FFT control snapshot/model status mismatch");
            if(actual.reads.size()!=expected.reads.size() || actual.writes.size()!=expected.writes.size() ||
               actual.commits.size()!=expected.commits.size() || actual.elapsed_cycles!=expected.elapsed_cycles)
                $fatal(1,"FFT trace length/completion mismatch: reads %0d/%0d writes %0d/%0d commits %0d/%0d cycles %0d/%0d",
                       actual.reads.size(),expected.reads.size(),actual.writes.size(),expected.writes.size(),actual.commits.size(),
                       expected.commits.size(),actual.elapsed_cycles,expected.elapsed_cycles);
            foreach(expected.initial_samples[i]) if(actual.initial_samples[i] !== expected.initial_samples[i]) $fatal(1,"Sample load mismatch at %0d",i);
            foreach(expected.twiddles[i]) if(actual.twiddles[i] !== expected.twiddles[i]) $fatal(1,"Twiddle load mismatch at %0d",i);
            foreach(expected.reads[i]) begin
                if(actual.reads[i].cycle!=expected.reads[i].cycle || actual.reads[i].address!==expected.reads[i].address ||
                   actual.reads[i].is_b!=expected.reads[i].is_b ||
                   (expected.reads[i].is_b && actual.reads[i].twiddle_address!==expected.reads[i].twiddle_address)) begin
                    if(errors<8) $display("Read %0d differs: actual=%p expected=%p",i,actual.reads[i],expected.reads[i]); errors++;
                end
            end
            foreach(expected.writes[i]) if(actual.writes[i] !== expected.writes[i]) begin
                if(errors<8) $display("Write %0d differs: actual=%p expected=%p",i,actual.writes[i],expected.writes[i]); errors++;
            end
            foreach(expected.commits[i]) if(actual.commits[i] !== expected.commits[i]) begin
                if(errors<8) $display("Commit %0d differs: actual=%p expected=%p",i,actual.commits[i],expected.commits[i]); errors++;
            end
            foreach(expected.final_samples[i]) if(actual.final_samples[i] !== expected.final_samples[i]) begin
                if(errors<8) $display("Final memory %0d differs: actual=%h expected=%h",i,actual.final_samples[i],expected.final_samples[i]); errors++;
            end
            save_result(actual,errors==0);
            if(errors) $fatal(1,"FFT verification failed with %0d mismatches; result saved to %s",errors,actual.result_file);
            $display("Scoreboard completed: N=%0d count=%0d reads=%0d writes=%0d commits=%0d cycles=%0d result=%s",
                     actual.points,actual.count,actual.reads.size(),actual.writes.size(),actual.commits.size(),actual.elapsed_cycles,actual.result_file);
            if(actual.end_last_sequence) $finish;
        end
    endtask
endclass
