import constant_functions_pkg::*;

class QueueMonitor #(type T, type I);
    ////////////////////////////////////////////////////////////////
    // Globally Defined Locally Set Parameters
    localparam DATA_DEPTH    = queue_DATA_DEPTH    (T::ADDR_WIDTH),
    localparam READ_LATENCY  = queue_READ_LATENCY  (T::REGISTERED_IN, T::REGISTERED_IN_BRAM),
    localparam WRITE_LATENCY = queue_WRITE_LATENCY (T::REGISTERED_IN, T::REGISTERED_IN_BRAM, T::READ_THEN_WRITE)
 
    `QUEUE_IO_OUT_STRUCT(T::NUMBER_OF_QUEUES, T::DATA_WIDTH, T::ADDR_WIDTH) 

    TriggerableQueueBroadcaster #(T) out_broadcaster;
    I inf;

    function new(TriggerableQueueBroadcaster #(T) out_broadcaster,
                 I inf);
        this.out_broadcaster = out_broadcaster;
        this.inf = inf;
    endfunction

    task automatic run();
        T io_obj;
        
        logic [WRITE_LATENCY - 1 : 0][0:0] wr_data_i_l; // 'l' for latency
        logic [READ_LATENCY - 1 : 0][0:0] rd_data_o_l; 


        logic valid;

        forever begin
            io_obj = new();

            if(inf.rst_i) begin
                wr_data_i_l[0] <= 0;
                rd_data_i_l[0] <= 0;
                
            end else begin
                if(inf.push_i) begin
                    wr_data_i_l[0] <= 1;
                end else begin
                    wr_data_i_l[0] <= 0;
                end
                if(inf.pop_i) begin
                    rd_data_i_l[0] <= 1;
                end else begin
                    wr_data_i_l[0] <= 0;
                end
            end

            if(wr_data_i_l && rd_data_i_l[])
            
            @(posedge inf.clk_i)

            for(int i = 1; i < WRITE_LATENCY; i++) begin
                wr_data_i_l[i] <= wr_data_i_l[i-1];
            end

            for(int i = 1; i < READ_LATENCY; i++) begin
                rd_data_o_l[i] <= rd_data_o_l[i-1];
            end
            
            @(negedge inf.clk_i);
            
            
        end
    endtask
endclass