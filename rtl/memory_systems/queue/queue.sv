/* 
Queue (aka FIFO). ADDR_WIDTH X DATA_WIDTH of instantiated memory  
should fit within a single bram for best performance. Without READ_THEN_WRITE
enabled, simultaneous push/pop when there is one element left on the queue
behavior is undefined. Behavior of pushing to a full queue or popping from an
empty one is considered as undefined and will throw the control state into
unknown territory.

Since the control state update has to happen in one latency cycle from the time the push/pop
is ushered, the read/write address _next values are calculated using the immediate 
push/pop signals even if REGISTERED_IN is enabled. Meaning ideally the push/pull signals 
should be free of any logic in higher modules. 

The more_than and less_than signals have the same issue since they are 
immediate, but enabling REGISTERED_IN will pipeline the logic (at the cost
of changes reflecting one cycle later as opposed to immediately)

ADDR_WIDTH:
- Sets the address width, also determines the data depth of the BRAM.

DATA_WIDTH:
- Data width.

REGISTERED_IN [0, 1]:
- If 1, inputs are registered, increasing latency by 1 cycle,
  else, inputs are direct.

REGISTERED_IN_BRAM [0, 1]:
- If 1, inputs of internal bram are first registered, increasing the latency by 1 cycle,
  else, inputs are direct.

READ_THEN_WRITE [0, 1]:
- If 1, read happens first then write on a separate cycle, allowing for simultaneous push/pop
  when there is one element left in the queue, at the cost of additional cycle of latency.

NUMBER_OF_QUEUES [1,..]:
- Specify how many queues to run in parallel. If > 1, allows for pushing to multiple queues that 
  share the same control state. Hence multiple corresponding read/write ports for push/pop. This
  assumes that fanout isn't an issue, otherwise its best to instantiate multiple queue modules with 
  separate control states or keep the number low.

*/

import constant_functions_pkg::*; 

module queue #(
    parameter ADDR_WIDTH,
    parameter DATA_WIDTH,
    parameter REGISTERED_IN,        // [0, 1]
    parameter REGISTERED_IN_BRAM,   // [0, 1]
    parameter READ_THEN_WRITE,      // [0, 1]
    parameter NUMBER_OF_QUEUES,     // [1,..]

    ////////////////////////////////////////////////////////////////
    // Globally Defined Locally Set Parameters
    localparam DATA_DEPTH = queue_DATA_DEPTH(ADDR_WIDTH),
    localparam LATENCY    = queue_LATENCY   (REGISTERED_IN, REGISTERED_IN_BRAM, READ_THEN_WRITE)
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
    output                      more_than_o, // more than 'more_than_i' elements on the queue
);

    // read/write port setting for REGISTERED_IN
    logic rst;

    logic                                                push;
    logic [NUMBER_OF_QUEUES - 1 : 0][DATA_WIDTH - 1 : 0] wr_data;
    logic                                                pop;

    logic [ADDR_WIDTH : 0] less_than;
    logic [ADDR_WIDTH : 0] more_than;


    always@(posedge clk_i) begin
        rst      <= rst_i;

        push     <= push_i;
        wr_data  <= wr_data_i;
        pop      <= pop_i;

        less_than <= less_than_i;
        more_than <= more_than_i;
    end

    logic rst_g;

    logic                                                push_g;
    logic [NUMBER_OF_QUEUES - 1 : 0][DATA_WIDTH - 1 : 0] wr_data_g;
    logic                                                pop_g;

    logic [ADDR_WIDTH : 0] less_than_g;
    logic [ADDR_WIDTH : 0] more_than_g;

    generate
        if(REGISTERED_IN == 1) begin
            assign rst_g = rst;

            assign push_g     = push;
            assign wr_data_g  = wr_data;
            assign pop_g      = pop;

            assign less_than_g = less_than;
            assign more_than_g = more_than;
        end else begin
            assign rst_g = rst_i;

            assign push_g     = push_i;
            assign wr_data_g  = wr_data_i;
            assign pop_g      = pop_i;

            assign less_than_g = less_than_i;
            assign more_than_g = more_than_i;
        end
    endgenerate


    // write state
    logic                                                en_0;
    logic                                                wr_en,
    logic [ADDR_WIDTH - 1 : 0]                           wr_addr;
    logic [NUMBER_OF_QUEUES - 1 : 0][DATA_WIDTH - 1 : 0] wr_data;

    logic [ADDR_WIDTH - 1 : 0]                           wr_addr_next;

    logic                                                en_0_delay;
    logic                                                wr_en_delay,
    logic [ADDR_WIDTH - 1 : 0]                           wr_addr_delay;
    logic [NUMBER_OF_QUEUES - 1 : 0][DATA_WIDTH - 1 : 0] wr_data_delay;

    // read state
    logic                                                en_1;
    logic [ADDR_WIDTH - 1 : 0]                           rd_addr;
    logic [NUMBER_OF_QUEUES - 1 : 0][DATA_WIDTH - 1 : 0] rd_data;

    logic [ADDR_WIDTH - 1 : 0]                           rd_addr_next;

    logic [NUMBER_OF_QUEUES - 1 : 0][DATA_WIDTH - 1 : 0] rd_data_delay;

    // control state
    logic unsigned [ADDR_WIDTH : 0] element_count;
    logic unsigned [ADDR_WIDTH : 0] element_count_next;
    logic                           element_count_ce;

    always@(posedge clk_i) begin
        // write update
        wr_addr       <= wr_addr_next;

        if(READ_THEN_WRITE == 1) begin
            en_0_delay    <= en_0;
            wr_en_delay   <= wr_en;
            wr_addr_delay <= wr_addr;
            wr_data_delay <= wr_data;
        end

        // read update
        rd_addr       <= rd_addr_next;

        if(READ_THEN_WRITE == 1) begin
            rd_data_delay <= rd_data;
        end

        // control state update
        if(element_count_ce) begin
            element_count <= element_count_next;
        end else begin
            element_count <= element_count;
        end
    end

    always_comb begin
        // push (write) logic
        en_0  = push_g;
        wr_en = push_g;
        if(push_g) begin
            wr_addr_next = wr_addr + 1;
        end else begin
            wr_addr_next = wr_addr;
        end

        wr_data = wr_data_g;

        // pop (read) logic
        en_1 = pop_g;
        if(pop_g) begin
            rd_addr_next = rd_addr + 1;
        end else begin
            rd_addr_next = rd_addr;
        end
        
        // control state
        if (rst_g) begin               
            element_count_next = element_count - element_count;
        end else if (push_i) begin      // push
            element_count_next = element_count + 1;
        end else begin                  // else, assume pop (see CE condition for element_count just below)
            element_count_next = element_count - 1;
        end 

        // CE condition for element_count update
        element_count_ce = (push_i ^ pop_i) & (!rst_g);

        // LUT4(push_i, pop_i, rst_g, element_count[i]) -> fast carry path -> element_count[i] if CE.
        // (push ^ pop) & (!rst_g) -> CE.

        if(rst_g) begin
            wr_addr_next       = 0;
            rd_addr_next       = 0;
        end
    end

    // Queue BRAM instantiations.
    generate
        for(genvar i = 0; i < NUMBER_OF_QUEUES; i++) begin
            if(READ_THEN_WRITE == 1) begin
                bram_dual_port_simple #(
                    .ADDR_WIDTH(ADDR_WIDTH),
                    .DATA_WIDTH(DATA_WIDTH),
                    .REGISTERED_IN(REGISTERED_IN_BRAM)
                ) queue_memory (
                    // write port
                    .clk_0_i  (clk_i),
            
                    .en_0_i   (en_0_delay),
                    .wr_en_i  (wr_en_delay),
                    .wr_addr_i(wr_addr_delay),
                    .wr_data_i(wr_data_delay[i]),

                    // read port
                    .clk_1_i(clk_i),

                    .en_1_i   (en_1),
                    .rd_addr_i(rd_addr),
                    .rd_data_o(rd_data[i])
                );
            end else begin
                bram_dual_port_simple #(
                    .ADDR_WIDTH(ADDR_WIDTH),
                    .DATA_WIDTH(DATA_WIDTH),
                    .REGISTERED_IN(REGISTERED_IN_BRAM)
                ) queue_memory (
                    // write port
                    .clk_0_i  (clk_i),
            
                    .en_0_i   (en_0),
                    .wr_en_i  (wr_en),
                    .wr_addr_i(wr_addr),
                    .wr_data_i(wr_data),

                    // read port
                    .clk_1_i(clk_i),

                    .en_1_i   (en_1),
                    .rd_addr_i(rd_addr),
                    .rd_data_o(rd_data[i])
                );
            end
        end
    endgenerate

    logic unsigned [ADDR_WIDTH : 0] more_than_g_u;
    logic unsigned [ADDR_WIDTH : 0] less_than_g_u;

    // essentially type casting to unsigned to avoid signed comparison in the output logic since element_count is unsigned.
    assign more_than_g_u = more_than_g[ADDR_WIDTH : 0];
    assign less_than_g_u = less_than_g[ADDR_WIDTH : 0];

    assign full_o  = $unsigned(DATA_DEPTH - 1) < element_count;
    assign empty_o = element_count             < $unsigned(1);

    assign less_than_o = element_count < less_than_g_u;
    assign more_than_o = more_than_g_u < element_count;

    assign rd_data_o = (READ_THEN_WRITE == 1) ? rd_data_delay : rd_data;
endmodule;