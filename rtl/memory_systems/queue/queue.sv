/* 
Queue (aka FIFO). 

With CONFLICT_PROOF enabled, simultaneous push/pop behavior is: 
    1. empty state push/pop performs write then read via write forwarding
    2. full state pop/push performs read then write via read forwarding

With CONFLICT_PROOF disabled, simultaneous push/pop behavior to full/empty queue is
undefined..

As usual, behavior to pushing to full queue or popping from empty queue is undefined.

Since the control state update has to happen in one latency cycle from the time the push/pop
is ushered, the read/write address _next values are calculated using the immediate 
push/pop signals even if REGISTERED_IN is enabled. Meaning ideally the push/pull signals 
should be free of any logic in higher modules. Same with the rst_i, less_than_i and
more_than_i signals. 

ADDR_WIDTH:
- Sets the address width, also determines the data depth of the BRAM.

DATA_WIDTH:
- Data width.

CONFLICT_PROOF [0, 1]:
- If 1, enables conflict proof simultaneous push/pull when queue is empty or full, as described
  above.

REGISTERED_IN [0, 1]:
- If 1, inputs are registered, increasing latency by 1 cycle,
  else, inputs are direct.

REGISTERED_IN_BRAM [0, 1]:
- If 1, inputs of internal bram are first registered, increasing the latency by 1 cycle,
  else, inputs are direct.

REGISTERED_OUT_BRAM [0, 1]:
- If 1, outputs of internal bram are registered to an additional pipelined register, greatly
  reducing routing pressure to CLB fabric.

NUMBER_OF_QUEUES [1,..]:
- Specify how many queues to run in parallel. If > 1, allows for pushing to multiple queues that 
  share the same control state. Hence multiple corresponding read/write ports for push/pop. This
  assumes that fanout isn't an issue, otherwise its best to instantiate multiple queue modules with 
  separate control states or keep the number of queues low.

*/

import constant_functions_pkg::*; 

module queue #(
    parameter ADDR_WIDTH,
    parameter DATA_WIDTH,
    parameter CONFLICT_PROOF,       // [0, 1]
    parameter REGISTERED_IN,        // [0, 1]
    parameter REGISTERED_IN_BRAM,   // [0, 1]
    parameter REGISTERED_OUT_BRAM,  // [0, 1]
    parameter NUMBER_OF_QUEUES,     // [1,..]

    ////////////////////////////////////////////////////////////////
    // Globally Defined Locally Set Parameters
    localparam DATA_DEPTH        = queue_DATA_DEPTH                  (ADDR_WIDTH),
    localparam READ_LATENCY      = queue_READ_LATENCY                (CONFLICT_PROOF, REGISTERED_IN, REGISTERED_IN_BRAM, REGISTERED_OUT_BRAM),
    localparam WRITE_LATENCY     = queue_WRITE_LATENCY               (CONFLICT_PROOF, REGISTERED_IN, REGISTERED_IN_BRAM),
    localparam READ_LATENCY_BRAM = bram_dual_port_simple_READ_LATENCY(REGISTERED_IN_BRAM, REGISTERED_OUT_BRAM)
) (
    input clk_i,
    input rst_i,

    // write port
    input                                                 push_i,
    input  [NUMBER_OF_QUEUES - 1 : 0][DATA_WIDTH - 1 : 0] wr_data_i,

    // read port
    input                                                 pop_i,
    output [NUMBER_OF_QUEUES - 1 : 0][DATA_WIDTH - 1 : 0] rd_data_o,

    // conditions
    output                      full_o,
    output                      empty_o,

    input  [ADDR_WIDTH : 0]     less_than_i, 
    output                      less_than_o, // less than 'less_than_i' elements on queue

    input  [ADDR_WIDTH : 0]     more_than_i,
    output                      more_than_o  // more than 'more_than_i' elements on the queue
);

    // read/write port setting for REGISTERED_IN
    logic                                                push;
    logic [NUMBER_OF_QUEUES - 1 : 0][DATA_WIDTH - 1 : 0] wr_data;
    logic                                                pop;
    logic                                                full;
    logic                                                empty;

    always@(posedge clk_i) begin
        push     <= push_i;
        wr_data  <= wr_data_i;
        pop      <= pop_i;
        full     <= full_o;
        empty    <= empty_o;
    end

    logic                                                push_g;
    logic [NUMBER_OF_QUEUES - 1 : 0][DATA_WIDTH - 1 : 0] wr_data_g;
    logic                                                pop_g;
    logic                                                full_g;
    logic                                                empty_g;

    generate
        if(REGISTERED_IN == 1) begin
            assign push_g     = push;
            assign wr_data_g  = wr_data;
            assign pop_g      = pop;
            assign full_g     = full;
            assign empty_g    = empty;

        end else begin
            assign push_g     = push_i;
            assign wr_data_g  = wr_data_i;
            assign pop_g      = pop_i;
            assign full_g     = full_o;
            assign empty_g    = empty_o;
        end
    endgenerate


    // write state
    logic                                                bram_forward_en_0;
    logic                                                bram_forward_wr_en;
    logic                           [ADDR_WIDTH - 1 : 0] bram_forward_wr_addr;
    logic                           [ADDR_WIDTH - 1 : 0] bram_forward_wr_addr_next;
    logic [NUMBER_OF_QUEUES - 1 : 0][DATA_WIDTH - 1 : 0] bram_forward_wr_data;

    logic                                                bram_normal_en_0;
    logic                                                bram_normal_wr_en;
    logic                           [ADDR_WIDTH - 1 : 0] bram_normal_wr_addr;
    logic [NUMBER_OF_QUEUES - 1 : 0][DATA_WIDTH - 1 : 0] bram_normal_wr_data;

    logic                                                bram_mux_en_0;
    logic                                                bram_mux_wr_en;
    logic                           [ADDR_WIDTH - 1 : 0] bram_mux_wr_addr;
    logic [NUMBER_OF_QUEUES - 1 : 0][DATA_WIDTH - 1 : 0] bram_mux_wr_data;

    // read state
    logic                                                bram_forward_en_1;
    logic                           [ADDR_WIDTH - 1 : 0] bram_forward_rd_addr;
    logic                           [ADDR_WIDTH - 1 : 0] bram_forward_rd_addr_next;

    logic                                                bram_normal_en_1;
    logic                           [ADDR_WIDTH - 1 : 0] bram_normal_rd_addr;

    logic                                                bram_mux_en_1;
    logic                           [ADDR_WIDTH - 1 : 0] bram_mux_rd_addr;

    logic [NUMBER_OF_QUEUES - 1 : 0][DATA_WIDTH - 1 : 0] bram_normal_rd_data;
    logic [NUMBER_OF_QUEUES - 1 : 0][DATA_WIDTH - 1 : 0] bram_backward_rd_data;
    
    logic [NUMBER_OF_QUEUES - 1 : 0][DATA_WIDTH - 1 : 0]    bram_mux_rd_data;
    logic                           [READ_LATENCY_BRAM : 0] bram_backward_rd_data_valid; // *** HERE ****

    // control state
    logic unsigned [ADDR_WIDTH : 0] element_count;
    logic unsigned [ADDR_WIDTH : 0] element_count_next;
    logic                           element_count_ce;

    always@(posedge clk_i) begin
        // write address update
        bram_forward_wr_addr <= bram_forward_wr_addr_next;

        // read address update
        bram_forward_rd_addr <= bram_forward_rd_addr_next;

        // control state update
        if(element_count_ce) begin
            element_count <= element_count_next;
        end else begin
            element_count <= element_count;
        end

        // set forwards to normal downstream register
        // where enables are voided in the case of forwarding

        // write forwarding condition: push/pop on empty 
        if(CONFLICT_PROOF == 1) begin
            if(empty_g & push_g & pop_g) begin
                bram_normal_en_0    <= 0;
                bram_normal_wr_en   <= 0;
            end else begin
                bram_normal_en_0    <= bram_forward_en_0;
                bram_normal_wr_en   <= bram_forward_wr_en;
            end
        end else begin
            bram_normal_en_0    <= bram_forward_en_0;
            bram_normal_wr_en   <= bram_forward_wr_en;
        end
        bram_normal_wr_addr <= bram_forward_wr_addr;
        bram_normal_wr_data <= bram_forward_wr_data;

        // read forwarding condition: push/pop on full
        if(CONFLICT_PROOF == 1) begin
            if(full_g & push_g & pop_g) begin
                bram_normal_en_1    <= 0;
            end else begin
                bram_normal_en_1    <= bram_forward_en_1;
            end
        end else begin
            bram_normal_en_1    <= bram_forward_en_1;
        end
        bram_normal_rd_addr <= bram_forward_rd_addr;

        // set backwards for just read output and accompanying valid pipeline
        bram_backward_rd_data          <= bram_normal_rd_data;
        bram_backward_rd_data_valid[0] <= full_g & push_g & pop_g; 
        for(int i = 1; i <= READ_LATENCY_BRAM; i++) begin      
            bram_backward_rd_data_valid[i] <= bram_backward_rd_data_valid[i-1];
        end
    end

    always_comb begin
        // push (write) logic and wiring
        bram_forward_en_0  = push_g;
        bram_forward_wr_en = push_g;
        if(push_g) begin
            bram_forward_wr_addr_next = bram_forward_wr_addr + 1;
        end else begin
            bram_forward_wr_addr_next = bram_forward_wr_addr;
        end
        bram_forward_wr_data = wr_data_g;

        // push (write) forwarding mux logic wiring
        if(CONFLICT_PROOF == 1) begin
            // write forwarding condition: push/pop on empty 
            if(empty_g & push_g & pop_g) begin
                bram_mux_en_0    = bram_forward_en_0;
                bram_mux_wr_en   = bram_forward_wr_en;
                bram_mux_wr_addr = bram_forward_wr_addr;
                bram_mux_wr_data = bram_forward_wr_data;
            end else begin
                bram_mux_en_0    = bram_normal_en_0;
                bram_mux_wr_en   = bram_normal_wr_en;
                bram_mux_wr_addr = bram_normal_wr_addr;
                bram_mux_wr_data = bram_normal_wr_data;
            end
        end else begin
            bram_mux_en_0    = bram_forward_en_0;
            bram_mux_wr_en   = bram_forward_wr_en;
            bram_mux_wr_addr = bram_forward_wr_addr;
            bram_mux_wr_data = bram_forward_wr_data;
        end

        // pop (read) logic
        bram_forward_en_1 = pop_g;
        if(pop_g) begin
            bram_forward_rd_addr_next = bram_forward_rd_addr + 1;
        end else begin
            bram_forward_rd_addr_next = bram_forward_rd_addr;
        end

        // pop (read) forwarding mux logic wiring
        if(CONFLICT_PROOF == 1) begin
            // read forwarding condition: push/pop on full
            if(full_g & push_g & pop_g) begin
                bram_mux_en_1    = bram_forward_en_1;
                bram_mux_rd_addr = bram_forward_rd_addr;
            end else begin
                bram_mux_en_1    = bram_normal_en_1;
                bram_mux_rd_addr = bram_normal_rd_addr;
            end
        end else begin
            bram_mux_en_1    = bram_forward_en_1;
            bram_mux_rd_addr = bram_forward_rd_addr;
        end

        // read out mux
        if(CONFLICT_PROOF == 1) begin
            if(bram_backward_rd_data_valid[READ_LATENCY_BRAM]) begin
                bram_mux_rd_data = bram_backward_rd_data;
            end else begin
                bram_mux_rd_data = bram_normal_rd_data;
            end
        end else begin
            bram_mux_rd_data = bram_normal_rd_data;
        end
        
        // control state
        if (rst_i) begin               
            element_count_next = 0;
        end else if (push_i) begin      // push
            element_count_next = element_count + 1;
        end else begin                  // else, assume pop (see CE condition for element_count just below)
            element_count_next = element_count - 1;
        end 

        // CE condition for element_count update
        element_count_ce = (push_i ^ pop_i) | rst_i;

        // LUT4(push_i, pop_i, rst_i, element_count[i]) -> fast carry path -> element_count[i] if CE.
        // (push_i ^ pop_i) | rst_i -> CE.

        if(rst_i) begin
            bram_forward_wr_addr_next = 0;
            bram_forward_rd_addr_next = 0;
        end
    end

    // Queue BRAM instantiations.
    generate
        for(genvar i = 0; i < NUMBER_OF_QUEUES; i++) begin
            bram_dual_port_simple #(
                .ADDR_WIDTH(ADDR_WIDTH),
                .DATA_WIDTH(DATA_WIDTH),
                .REGISTERED_IN(REGISTERED_IN_BRAM),
                .REGISTERED_OUT(REGISTERED_OUT_BRAM)
            ) queue_memory (
                // write port
                .clk_0_i  (clk_i),
            
                .en_0_i   (bram_mux_en_0),
                .wr_en_i  (bram_mux_wr_en),
                .wr_addr_i(bram_mux_wr_addr),
                .wr_data_i(bram_mux_wr_data[i]),

                // read port
                .clk_1_i(clk_i),

                .en_1_i   (bram_mux_en_1),
                .rd_addr_i(bram_mux_rd_addr),
                .rd_data_o(bram_normal_rd_data[i])
            );
        end
    endgenerate

    logic unsigned [ADDR_WIDTH : 0] more_than_g_u;
    logic unsigned [ADDR_WIDTH : 0] less_than_g_u;

    // essentially type casting to unsigned to avoid signed comparison in the output logic since element_count is unsigned.
    assign more_than_g_u = more_than_i[ADDR_WIDTH : 0];
    assign less_than_g_u = less_than_i[ADDR_WIDTH : 0];

    assign full_o  = $unsigned(DATA_DEPTH - 1) < element_count;
    assign empty_o = element_count             < $unsigned(1);

    assign less_than_o = element_count < less_than_g_u;
    assign more_than_o = more_than_g_u < element_count;
    
    assign rd_data_o = bram_mux_rd_data;
endmodule