package monitors_pkg;
    import utilities_pkg::*;
    `include "MultistageFanoutMonitor.sv"
    `include "QueueMonitor.sv"
    `include "MaxMonitor.sv"
    `include "PriorityEncoderMonitor.sv"
    `include "MultistageMuxMonitor.sv"
    `include "EqualMonitor.sv"
    `include "ReductionTreeMonitor.sv"
    `include "AlignerMonitor.sv"
    `include "PackerMonitor.sv"
    `include "ReservoirMonitor.sv"
    `include "QueuePushCouplerMonitor.sv"
    `include "QueuePopCouplerMonitor.sv"
    `include "QueueCarriageMonitor.sv"
    `include "QueueTrainMonitor.sv"
    `include "ReservoirNoBackpressureMonitor.sv"
endpackage
