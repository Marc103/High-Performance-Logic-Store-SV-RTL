package generators_pkg;
    import utilities_pkg::*;
    `include "MultistageFanoutGenerator.sv"
    `include "QueueGenerator.sv"
    `include "MaxGenerator.sv"
    `include "PriorityEncoderGenerator.sv"
    `include "MultistageMuxGenerator.sv"
    `include "EqualGenerator.sv"
    `include "ReductionTreeGenerator.sv"
    `include "AlignerGenerator.sv"
    `include "PackerGenerator.sv"
    `include "ReservoirGenerator.sv"
    `include "QueuePushCouplerGenerator.sv"
    `include "QueuePopCouplerGenerator.sv"
    `include "QueueCarriageGenerator.sv"
    `include "QueueTrainGenerator.sv"
    `include "ReservoirNoBackpressureGenerator.sv"
endpackage
