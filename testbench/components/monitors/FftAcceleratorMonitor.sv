import constant_functions_pkg::*;
class FftAcceleratorMonitor #(type T, type I);
    `FFT_ACCELERATOR_IO_IN_STRUCT(T::SAMPLES_ADDR_WIDTH)
    `FFT_ACCELERATOR_IO_OUT_STRUCT
    typedef T::write_event_t write_event_t;
    typedef T::read_event_t read_event_t;
    TriggerableQueueBroadcaster #(T) out_broadcaster;
    TriggerableQueue #(T) monitor_metadata;
    TriggerableQueue #(T) snapshot_requests, snapshot_done;
    I inf;
    bit active=0, seen_busy=0;
    function new(TriggerableQueueBroadcaster #(T) out_broadcaster, I inf, TriggerableQueue #(T) monitor_metadata,
                 TriggerableQueue #(T) snapshot_requests, TriggerableQueue #(T) snapshot_done);
        this.out_broadcaster=out_broadcaster; this.inf=inf; this.monitor_metadata=monitor_metadata;
        this.snapshot_requests=snapshot_requests; this.snapshot_done=snapshot_done;
    endfunction
    task automatic run();
        T obj, metadata;
        fft_accelerator_io_in_t controls;
        fft_accelerator_io_out_t status;
        write_event_t write_event;
        read_event_t read_event;
        longint unsigned start_clock, elapsed;
        forever begin
            // Gate-level outputs are observed at the external memory sampling
            // edge, before NBA/clock-to-Q updates for the following cycle.
            if(T::PORT_SAMPLE_AT_POSEDGE) @(posedge inf.clk_i);
            else @(negedge inf.clk_i);
            if(inf.start_sequence) begin
                if(active) $fatal(1,"Overlapping FFT jobs");
                obj=new(); active=1; seen_busy=0;
                start_clock=inf.clock_count+(T::PORT_SAMPLE_AT_POSEDGE ? 1 : 0);
                monitor_metadata.pop(metadata);
                obj.points=int'(inf.fft_point_size_i); obj.count=int'(inf.fft_whole_iterations_i);
                obj.samples_file=metadata.samples_file; obj.twiddles_file=metadata.twiddles_file; obj.result_file=metadata.result_file;
                obj.sample_order_points=metadata.sample_order_points; obj.twiddle_points=metadata.twiddle_points;
                obj.sample_rate_hz=metadata.sample_rate_hz;
                obj.initial_samples=metadata.loaded_samples;
                obj.twiddles=metadata.loaded_twiddles;
                controls={inf.rst_i,inf.go_i,inf.fft_point_size_i,inf.fft_whole_iterations_i};
                obj.fft_accelerator_io_in_q.push_back(controls);
            end
            if(active) begin
                elapsed=inf.clock_count-start_clock;
                if(inf.busy_o) seen_busy=1;
                if(seen_busy && !inf.busy_o && !inf.fft_done_o) $fatal(1,"Busy dropped before final commitment");
                if(inf.twiddles_rd_en_o && !inf.samples_rd_en_o) $fatal(1,"Twiddle read without a sample read");
                if(inf.samples_rd_en_o) begin
                    read_event.cycle=elapsed; read_event.address=inf.samples_rd_addr_o;
                    read_event.twiddle_address=inf.twiddles_rd_addr_o; read_event.is_b=inf.twiddles_rd_en_o;
                    obj.reads.push_back(read_event);
                end
                if(inf.samples_wr_en_o) begin
                    write_event.cycle=elapsed; write_event.address=inf.samples_wr_addr_o;
                    write_event.data=inf.samples_wr_data_o; obj.writes.push_back(write_event);
                end
                if(inf.commit_en) begin
                    write_event.cycle=elapsed; write_event.address=inf.commit_address;
                    write_event.data=inf.commit_data; obj.commits.push_back(write_event);
                end
                if(inf.end_sequence) begin
                    if(!inf.fft_done_o || inf.busy_o) $fatal(1,"Invalid FFT completion marker");
                    obj.elapsed_cycles=elapsed;
                    snapshot_requests.push(obj); snapshot_done.pop(obj);
                    status={inf.busy_o,inf.fft_done_o}; obj.fft_accelerator_io_out_q.push_back(status);
                    obj.end_last_sequence=inf.end_last_sequence;
                    out_broadcaster.push(obj); active=0;
                end
            end else if(!inf.loading && !inf.rst_i && (inf.samples_rd_en_o || inf.samples_wr_en_o || inf.twiddles_rd_en_o))
                $fatal(1,"Memory traffic outside an active FFT job");
        end
    endtask
endclass
