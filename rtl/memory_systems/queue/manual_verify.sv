"
localparam DATA_DEPTH = queue_DATA_DEPTH(ADDR_WIDTH),
"
- defined as 
"
    return (2 ** ADDR_WIDTH);
"
- valid for ADDR_WIDTH > 0, which is not guarded 
- otherwise correct, 2 ** ADDR_WIDTH is the DATA_DEPTH
[]

"
localparam LATENCY    = queue_LATENCY   (REGISTERED_IN, REGISTERED_IN_BRAM, READ_THEN_WRITE)
"
- defined as
"
        int a = 0;
        if(REGISTERED_IN)    a += 1;
        if(READ_THEN_WRITE)  a += 1;
        return (a + bram_dual_port_simple_LATENCY(REGISTERED_IN_BRAM));
"
- order of arguments passed in is correct
- if conditions should be tightened to be more precise, a bit of renaming and organizing
  to make it clear.
- redefined as
"
        int latency = bram_dual_port_simple_LATENCY(REGISTERED_IN_BRAM);
        if(REGISTERED_IN == 1)    latency += 1;
        if(READ_THEN_WRITE == 1)  latency += 1;
        return latency;
"
- order of arguments passed in is correct
- starting 'int a = bram_dual_port_simple_LATENCY(REGISTERED_IN_BRAM);' is correct as that is
  the base latency.
- enabling either REGISTERED_IN or READ_THEN_WRITE adds a cycle of latency, hence if
  statements are correct.
[]

"
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
"
- signals present, correct
- bit widths and packed dimensions are correct for each signal 
- directions are correct
- 'less_than_i' and 'more_than_i' have the intentional bit width of "ADDR_WIDTH : 0"
  instead of "ADDR_WIDTH - 1 : 0" 
- default net type is wire, default signdness is unsigned, which is correct
[]


"
    // read/write port setting for REGISTERED_IN
    logic rst;

    logic                                                push;
    logic [NUMBER_OF_QUEUES - 1 : 0][DATA_WIDTH - 1 : 0] wr_data;
    logic                                                pop;

    logic [ADDR_WIDTH : 0] less_than;
    logic [ADDR_WIDTH : 0] more_than;
"
- type logic is correct
- packed bit width correct
[]

"
    always@(posedge clk_i) begin
        rst      <= rst_i;

        push     <= push_i;
        wr_data  <= wr_data_i;
        pop      <= pop_i;

        less_than <= less_than_i;
        more_than <= more_than_i;
    end
"
- left hand signals are present, correct
- right hand signals are present, correct
- no type mismatch, correct
- clk_i for posedge is correct

"
    logic                                                push_g;
    logic [NUMBER_OF_QUEUES - 1 : 0][DATA_WIDTH - 1 : 0] wr_data_g;
    logic                                                pop_g;

    logic [ADDR_WIDTH : 0] less_than_g;
    logic [ADDR_WIDTH : 0] more_than_g;
"
- type logic is correct
- packed bit width correct
[]

"
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
"
- left hand signals are present, correct
- right hand signals are present, correct
- no type mismatch, correct
- logic of if condition "REGISTERED_IN == 1"
    - left hand signals represent registered inputs
    - else left hand signals represent immediate inputs
    - which is correct
[]

"
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
"
- type logic is correct
- packed bit width correct
[]

"
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
"