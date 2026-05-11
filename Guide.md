## Assumed Knowledge
- basically, functionally correct code. 'Synthesizable' RTL. 
- things to look out for

## Logic Delay
- pipelining
    - faster clock, more area (pipeline registers)? Main tradeoff is increased latency for faster clock.
    - super wide combinatorial logic achieves short delay but consumes potentially a lot of area and introduces routing congesting issues
    - thin but deep combinational logic has a very long delay but consumes an optimal amount of area
    - so the idea is to write logic as first deep combinational logic and pipeline it! You get minimal area + additional area incurred by the pipeline registers* and fast clock frequency. If you don't care about latency (which turns out many many designs don't), adding a cycle or two (or five for that matter) is almost always beneficial. The only time (besides latency critical performance obviously) is when you are okay with long delays, aka low frequency clocks.
    - *expensive logic is always expensive no matter what. If you have complicated logic, then express it as a deep logic to minimize area as oppose to wide logic, then pipeline it, you will have so many pipeline registers that it becomes a serious overhead comparable to the actual logic itself. If you don't need high speed, great, you can reduce pipelining but then well, your clock is slow. So there's no work around besides clever algorithmic optimizations that make the actual logic itself much simpler (which there is tons of literature on simplifying logic).
- logical restructuring and optimization, a note on synthesis behavior
    - i.e classic adder tree example
    - faster clock, less area


## Routing Delay
- structured vs unstructured design
- some physical dimensions
    - lut to register bits ratio
- fanout in particular

## Design Philosophy
- Parameter Negotiation
    - issues with System Verilog and its limited expressiveness
    - why languages like Chisel exist
    - my personal experience and conclusion
    - using only packed dimensions
        - idea of oversized functions to enable flexible parameterization
        - extension, oversized structs
    - leading to high level generation and connection methodology.

    - Solved with Global Defined Locally Set (GDLS) functions
        1. parameters may not have a default value and their type is int (32-bit signed)
            - although, they maybe reinterpreted as a FP32 number.
        2. local parameters must be defined and turned into GDLS parameters using GDLS functions so that they are easily accessible by encasing modules.
            - ideally the GDLS functions themselves invoke other GDLS functions whenever possible
              to maximize reuse. See examples of how these functions are written.
            - truly local parameters may exist, but this should only be done if the user is 100% certain that an encasing module would never need that information. This isn't advisable, all truly
            local parameters are a subset of GLDS parameters, so why bother having them?
      
    
    - Problems with GDLS functions
        - First a note, GDLS functions are used purely to set parameters, not for generating the circuits themselves. So they can be expressive in how the parameters are set, i.e calculating what the total latency should be, supplying 2D (packed) arrays etc.. but not for the actual RTL itself.
        - Now the issue; imagine you have some function that is parameterized and defined in a shared package. Unfortunately, if you needed to use the same function with different parameters within the same design, you're out of luck, back to hardcoding.
        - Solution, use 'oversized' functions. We set the bit widths to the maximal probable bit width we think will be used in the future, then bit select to the particular parameter. This leads to further discussion on the nature of constant functions (functions whos inputs are constants and returns constant values).
            - For multidimensional support, only packed types can be used as inputs and return values.
            - This bleeds into synthesizable RTL, because it means unpacked types in ports are banned and in the main code should be avoided (except for memories), so that the oversized functions are compatible with the RTL code. This also means that the overridable parameterized themselves need to be written in the same oversized manner in the case of using multidimensional arrays.
            - with a reminder to point 1. in GDLS functions, the base unit of the packed type (first, or last dimension however you see it), is a 32-bit int
            - e.g a 2d packed array would be 'int [2:0][3:0] a;'. An array with 3 rows and 4 columns of type int. 

    - Problems with interfaces
        - The parameterization of interfaces at first glance appears quite useful (and indeed is) but what I found is that ironically it simultaneously makes them inflexible. Why? because the same interface (with how System Verilog) cannot be used to represent two modules with different values of their parameters, let me explain; Let's say I have 'N' number of modules to generate, all with the same interface, but parameterized differently. It would be nice to generate the bundle of interfaces that I can pass into each of the modules (btw, an 'array of interfaces' in my experience is a super buggy thing to do for synthesizable RTL) in the generate statement but I can't do that because they are parameterized differently. One solution is to set the parameters to the max value bit widths then in each iteration of the for loop generating the modules, manually connect them according to their widths. But what if (as is the intended case often), the modules themselves require you to pass the interfaces directly (meaning the input port is an interface)? I suppose you could within the module do bit selects to the passed in interface, but this is super messy and not backwards compatible.
        - Solution is, similarly to oversized functions, instead to use 'oversized' structs. These structs are defined with logic bit widths that we determine (by peering into a crystal ball) will never be exceeded in the future. Then we instantiate an array of them, and per generate module, wire them with bit selects as per parameter.

    - An additional point, 'oversized' parameter structs
        - Similar to an overised struct, and oversized parameter struct is intended to be able to maintain the information for the overridable parameters and is itself flexible to different modes of parameterization since its written in the same oversized manner. 

    - Brining everything together, the Mapper Construct
        - Here's an idea; Wouldn't it be nice if we could map on some 2D array modules, their respective parameters and the connections between without having to sit down and write the verilog code itself. Something like a MAP, FROM, TO, PARAMS... With how we set up everything above, this can be done!
        - We have a unified method to 'access' (really determine) local parameters of a module and a way to describe a common 'interface' and parameters via structs but are missing the definition of how modules may be connected together.
            - (Module type A) x (with params A) x (Module type B) x (with params B). That's many combinations to consider. Luckily, we don't have too and, if possible, layout the rules for varying parameters. We write a giant case statement in the top level mapper file detailing how combinations of modules and their parameters should be connected, then iterate through the 2D arrays:
                1. generate the modules found in MAP, wiring them to their oversized structs using bit selects determined by the specific parameters in PARAMS
                2. connect them using FROM, TO and defined connection rules
            - And that's it! It might sound complicated but it's not, see code examples for clarification.
    
    - A lot of the implementation techniques of the solutions here are workarounds for the limitations that System Verilog has as a language. However, I think it is also true that the core design challenges here are language agnostic. That a better language would have a more elegant form of implementation (i.e., not using oversized anything) but wouldn't inherently solve these design challengs.  

    - On to High Level Synthesis (HLS)
        - Wouldn't it be nice if we didn't have to manually populate the 2D MAP, FROM, TO, PARAMS arrays?... I think you get the idea.
    
## Manual Verification with AI Assistance
- having a simple to moderately complex testbench clears out about 95% bugs
- the issue is creating very complex testbench takes exponentially more time and just to clear out the remaining 5%. It really isn't scalable and for small (or solo) dev teams just takes too much time
- my solution is to use 'manual verification'. It is text file where each line or block of code is explained in a verbose manner and then proof read several times by the author and others.
    - it's sort of like trying to mathematically prove something. Statements are made then stand on axioms or other trusted proofs. The only real way to know if it is correct is if many people take a look at it and agree.
    - in the case where just the author is available, the best to do is verify it several times on different days,
    each time reading it as if for the first time.
- then after completing the manual verification, feed it into AI with the rtl and
  ask to look at it. Review it's response.

## File Checklist Work Flow
- to be performed in this order but not strictly
    - "------" does signify a hard order block, you really want to make sure
    the functionality and parameterization of the RTL is fully specified and frozen. Changing
    it after starting the testbench process will require touching every file in the testbench
    components related to the specific testbench.
- 1. to 3. are developed together
- 5. essentially decides the complexity of the testbench since the Generator creates these objects
  and the Driver uses these objects to drive stimulus input. So again, needs to be carefully designed and frozen.
  - i.e. lets says instead of driving simple input .packets of random data, you want to drive complex sequences
- 6. needs to be designed with great care. It is always possible that both the RTL and golden model are wrong but in the same way.
  The whole point of FEV is that we are comparing a clock accurate RTL and a easier to write software golden model and that by comparing
  the two perspectives, it will reveal bugs in either side.
- 7. to 10. are developed in a tightly coupled manner with 5.

1.  RTL           : rtl/.../module_name/module_name.sv
2.  RTL utilities : rtl/rtl_utilites_pkg.sv
    - Module IDs
    - Non-module specific constant functions 
    - Module specific oversized structs
    - Module specific constant functions
3.  Manual Verify : rtl/.../module_name/manual_verify_xxx.mv 
------------------------------------------------------------------------------
4.  Interface      : testbench/components/interfaces/module_name_inf.svh
------------------------------------------------------------------------------
5.  Main Class     : testbench/components/utilities/ModuleNameClass.sv
------------------------------------------------------------------------------
6.  Golden Model   : testbench/components/golden_models/ModuleNameModel.sv 
------------------------------------------------------------------------------
7.  Generator      : testbench/components/generators/ModuleNameGenerator.sv
8.  Driver         : testbench/components/drivers/ModuleNameDriver.sv
9.  Monitor        : testbench/components/monitors/ModuleNameMonitor.sv
10. Scoreboard     : testbench/components/scoreboards/ModuleNameScoreboard.sv
------------------------------------------------------------------------------
11. Utilities  pkg : testbench/package_manager/drivers_pkg.svh
12. Generator  pkg : testbench/package_manager/generators_pkg.svh
13. Driver     pkg : testbench/package_manager/drivers_pkg.svh
14. Monitor    pkg : testbench/package_manager/monitors_pkg.svh
15. Scoreboard pkg : testbench/package_manager/scoreboads_pkg.svh
16. Utilites   pkg : testbench/package_manager/utilities_pkg.svh
------------------------------------------------------------------------------
17. Testbench      : testbench/module_name_tb/module_name_tb.sv
18. Simulate       : testbench/module_name_tb/simulate.bat or simulate.sh (or both)

- in summary
    - writing the RTL code requires at least 3 files 
    - writing the testbench requires at least 15 files
- many of the testbench files have a similar structure as the example files and hence are
copies of modified versions of them
- maybe one day i'll write some python script that autogens these files with the base template
and module name...
