/*
Reservoir, a ready/valid fifo cache that tackle 3 issues:
1. Zero latency reaction time: Data from the reservoir is immediately available to the consumer 
   in the WATERMARK_ENTRIES.
    - The issue is caused by stall bubbles of upstream logic due to 'spool up' time
2. Handles backpressure: Late arriving data is buffered in BACK_PRESSURE_ENTRIES
    - The issue is caused by upstream logic that has 'spool down' time
3. Burst mode management
    - Using 'drain_watermark_o', downstream logic can know if at at least WATERMARK_ENTRIES 
      are available for consumption.

-------------- BACKPRESSURE_ENTRIES = 2
[-] - top entry is the 'top' of the reservoir, exists at index [0]
[-]
-------------- WATERMARK_ENTRIES = 3
[-]
[-]
[-] - bottom entry is the 'bottom' of the reservoir, exists at index [ENTRIES - 1]

* ENTRIES = WATERMARK_ENTRIES + BACKPRESSURE_ENTRIES;

It works like a water tank (hence reservoir) and functionally like a FIFO but without explicit read/write pointers.
New entries fall to the bottom most unoccupied entry, then the bottom most entry is exposed to the consumer. The reservoir
will assert 'fill_ready_o' until at least WATERMARK_ENTRIES are present, then we rely on the BACKPRESSURE_ENTRIES to handle
backpressure.

There really are only two scenarios where it's possible this module wouldn't be productive:
1. Intermittent upstream data arriving and low latency requirements. Say the producer produces data very sparsely
   but we wish the consumer to react in zero cycles.
    a. Synchronous case: If this is truly the behavior required then why have a buffer at all? And if you still need
       a buffer (i.e sometimes along the sparse activity we get bursts that the producer can't keep up with), then
       what you need is a first-word fall-through (FTWT) fifo with the control signals directly wired to read/write logic.
       Unfortunately, the long combinatorial logic paths of the control signals slow down the clock signficantly and 
       there are no RTL level logic optimizations to solve this on FPGAs. Well actually there is, which is to make 
       the buffer very shallow (i.e 4/8 entries corresponds to 2/3 bit width addresses) and so if your use case is such 
       then that is what I would recommend; in that case such a module 'queue_zero_latency' will be developed.
    b. Asynchronous case: The latency caused by the synchronization flip-flops stages inherently prohibits (at least to
       the best of my knowledge) zero latency requirements (especially at very high clock rates, where three stages would 
       be necessary to meet suitable metastability MTBF), and I highly doubt that trying to minimize the latency is worth 
       the diminshed clock rates.
2. Slow 'drain_ready_i' signal. If the downstream device produces a ready signal that has a lengthy propagation delay due to
   dense combinatorial delay, then since we don't register it, the clock will have to run slower. But this is an 
   unreasonable concern.
    a. If we did register it, we wouldn't be able to satisfy the zero latency reaction
    b. This would mean that the designer of that device has either accepted a lower clock or hopes that the user will register it and auto-retiming done by a
       synthesis tool will help. Can't do much about the first issue. Second issue implicitly assumes that even if we do register the ready signal, we processes it
       very lightly which would enable effective retiming, which is an unreasonable assumption to make.
    c. Now assuming normal amount of propagation delay on the 'drain_ready_i', it is acceptable to add small bitwise and gate to it.

To summarize, if 'spool up' and 'spool down' times can't be effectively ammortized by active times, the effectiveness of this module is also reduced.





*/

import constant_functions_pkg::*;

module reservoir #(
    parameter DATA_WIDTH,
    parameter WATERMARK_ENTRIES,
    parameter BACKPRESSURE_ENTRIES

    ////////////////////////////////////////////////////////////////
    // Globally Defined Locally Set Parameters
    localparam ENTRIES = WATERMARK_ENTRIES + BACKPRESSURE_ENTIRES // reservoir_ENTIRES(WATERMARK_ENTIRES, BACKPRESSURE_ENTRIES)
) (
    input clk_i,
    input rst_i,

    // Fill side
    input [DATA_WIDTH - 1 : 0] fill_data_i,
    input                      fill_valid_i,

    output                     fill_ready_o,

    // Drain side
    input                       drain_ready_i,

    output [DATA_WIDTH - 1 : 0] drain_data_o,
    output                      drain_valid_o,
    output                      drain_watermark_o,
);

logic [ENTRIES - 1 : 0][DATA_WIDTH - 1 : 0] reservoir;
logic [ENTRIES - 1 : 0][DATA_WIDTH - 1 : 0] reservoir_next;

logic [ENTRIES - 1 : 0] occupied;
logic [ENTRIES - 1 : 0] occupied_next;

logic [ENTRIES - 1 : 0] ce;
logic [ENTRIES - 1 : 0] bottom_most_free;
logic [ENTRIES - 1 : 0] preemptive_bottom_most_free;

logic fill;
logic drain;

always_comb begin
    // assumes BACKPRESSURE_ENTRIES sufficiently large enough to handle backpressure.
    fill = fill_valid_i; 

    // can't drain if the reservoir is empty.
    drain = reservoir_occupied[ENTRIES - 1] & drain_ready_i;

    // default CE value, if draining everything gets active
    for(int i = 0; i < ENTRIES; i++) begin
        reservoir_ce[i] = drain;
    end

    // determine the bottom most free, used for (fill, !drain)
        // if:
        // unoccupied and most bottom entry (index [ENTRIES - 1])
        // else:
        // unoccupied and just below is occupied
    for(int i = 0; i < ENTRIES; i++) begin
        if(i == (ENTRIES - 1)) begin
            bottom_most_free[i] = !occupied[i];
        end else begin
            bottom_most_free[i] = (!occupied[i]) & occupied[i + 1];
        end
    end

    // determine the preemptive bottom most free, used for (fill, drain)
        // if:
        // occupied and top most entry (index [0])
        // which is bottom_most_free[i - 1]
       
    for(int i = 0; i < ENTRIES; i++) begin
        if(i == 0) begin
            preemptive_bottom_most_free[i] = occupied[i]
        end else begin
            preemptive_bottom_most_free[i] = bottom_most_free[i + 1];
        end
    end

    if((fill) && (!drain)) begin // Fill Only
        // If the entry is not occupied and below is occupied OR
        // if the entry is not occupied but it is the bottom entry
        for(int i = 0; i < ENTRIES; i++) begin
            
        end
        
    end else if((!fill) & drain) begin // Drain Only
        
    end else if(fill & drain) begin // Fill and Drain
        
    end else begin // No Fill, No Drain (no change)
        
    end

    // Else, no change

    // reset
    if(rst_i) begin
        for(int i = 0; i < ENTRIES; i++) begin
            reservoir_occupied_next[i] = 0;
        end
    end

end


endmodule