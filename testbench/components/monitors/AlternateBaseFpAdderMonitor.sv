import constant_functions_pkg::*;

class AlternateBaseFpAdderMonitor #(type T, type I);
    `ALTERNATE_BASE_FP_ADDER_IO_OUT_STRUCT(T::DATA_WIDTH)
    TriggerableQueueBroadcaster #(T) out_broadcaster;
    I inf;
    T current;
    bit input_active = 0;
    bit output_active = 0;
    bit [T::LATENCY : 0] valid_l = '0;
    bit [T::LATENCY : 0] start_l = '0;
    bit [T::LATENCY : 0] end_l = '0;
    bit [T::LATENCY : 0] final_l = '0;

    function new(TriggerableQueueBroadcaster #(T) out_broadcaster, I inf);
        this.out_broadcaster = out_broadcaster;
        this.inf = inf;
    endfunction

    task automatic record_output(bit start_item, bit valid_item, bit end_item, bit final_item);
        alternate_base_fp_adder_io_out_t transaction;
        if(start_item) begin
            if(output_active) $fatal(1, "Overlapping monitored sequences");
            current = new();
            output_active = 1;
        end
        if(valid_item) begin
            if(!output_active) $fatal(1, "Output without an active sequence");
            transaction.sum_o = inf.sum_o;
            current.alternate_base_fp_adder_io_out_q.push_back(transaction);
        end
        // An idle last item still terminates and publishes the sequence.
        if(end_item) begin
            if(!output_active) $fatal(1, "End marker without an active sequence");
            current.end_last_sequence = final_item;
            out_broadcaster.push(current);
            output_active = 0;
        end
    endtask

    task automatic run();
        forever begin
            @(negedge inf.clk_i);
            if(inf.start_sequence) input_active = 1;
            if(T::LATENCY == 0) begin
                record_output(inf.start_sequence, input_active && !inf.idle,
                              input_active && inf.end_sequence, inf.end_last_sequence);
            end else begin
                // Shift high-to-low so each old marker advances exactly once.
                // Start markers are delayed too, preserving adjacent sequences.
                for(int i = T::LATENCY; i > 0; i--) begin
                    valid_l[i] = valid_l[i - 1];
                    start_l[i] = start_l[i - 1];
                    end_l[i] = end_l[i - 1];
                    final_l[i] = final_l[i - 1];
                end
                valid_l[0] = input_active && !inf.idle;
                start_l[0] = inf.start_sequence;
                end_l[0] = input_active && inf.end_sequence;
                final_l[0] = inf.end_last_sequence;
                record_output(start_l[T::LATENCY], valid_l[T::LATENCY],
                              end_l[T::LATENCY], final_l[T::LATENCY]);
            end
            if(inf.end_sequence) input_active = 0;
        end
    endtask
endclass
