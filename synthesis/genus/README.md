# Nangate45 Genus synthesis

This flow synthesizes `fft_accelerator` with a **2 ns clock (500 MHz)** using
Genus **Stylus/Common UI** and all five supplied Nangate45 **NLDM** PVT corners.
It creates one common mapped implementation, not five independently synthesized
designs. All five views are active for setup and hold; each receives its own
timing reports and SDF for later gate-level simulation.

The top remains `fft_accelerator`, with external sample and twiddle memory ports.
The source list includes only its 13 RTL dependencies, package first. It excludes
the FPGA out-of-context wrapper, testbench classes and memory models.

## Run on the Genus device

Copy this repository, including the current accelerator RTL and utility package,
to the Linux device with Genus installed and its license environment configured.
From the repository root:

```bash
# Python 3.6+; downloads only the selected libraries, cell model and notices.
python3 synthesis/genus/fetch_nangate.py

mkdir -p synthesis/genus/runs
genus -no_gui -batch -files synthesis/genus/synth_fft_accelerator.tcl \
  -log synthesis/genus/runs/abfp32_500mhz.log
```

Launch a fresh Common UI process; do not add `-legacy_ui`. The script resolves
source paths relative to itself, so it also works when launched from another
directory with an absolute `-files` path. It exits nonzero on Tcl/tool errors.
An existing output directory is rejected to preserve prior netlists/reports.
Choose another run directory to repeat:

```bash
FFT_GENUS_OUT="$PWD/synthesis/genus/runs/abfp32_500mhz_run2" \
  genus -no_gui -batch -files synthesis/genus/synth_fft_accelerator.tcl
```

For **csh/tcsh** (the shell reporting `Illegal variable name` for a Bash-style
assignment), set the environment variable separately before launching Genus:

```csh
setenv FFT_GENUS_OUT "$cwd/synthesis/genus/runs/ii4_`date +%Y%m%d_%H%M%S`"
genus -no_gui -batch -files synthesis/genus/synth_fft_accelerator.tcl
```

Use the shell syntax appropriate to your session; RHEL itself does not require
changing the synthesis flow.

To use an existing copy of the requested library instead of downloading:

```bash
NANGATE_ROOT=/path/to/NangateOpenCellLibrary \
  genus -no_gui -batch -files synthesis/genus/synth_fft_accelerator.tcl
```

In csh/tcsh, use `setenv NANGATE_ROOT /path/to/NangateOpenCellLibrary`, then run
the same `genus` command on the following line.

`NANGATE_ROOT` is the directory **containing `Front_End`**, not the NLDM directory.
For an offline synthesis device, run the downloader elsewhere and copy its entire
`NangateOpenCellLibrary` directory, including `LICENSE` and `source_manifest.json`.
Downloaded libraries and run products are ignored by Git.

## Library inputs

Source: [the requested Liberty directory](https://github.com/JulianKemmerer/Drexel-ECEC575/tree/master/Encounter/NangateOpenCellLibrary/Front_End/Liberty),
pinned by the downloader to revision
`6f388c0cd9fb9902dabb6cf977b6208d7fd54c92`. Each file is
`Front_End/Liberty/NLDM/NangateOpenCellLibrary_<corner>.lib`.
The `functional.lib` sibling and the CCS/ECSM subdirectories are not timing inputs.

| Corner | Nominal voltage | Temperature |
| --- | --- | --- |
| `typical` | 1.10 V | 25 C |
| `slow` | 0.95 V | 125 C |
| `fast` | 1.25 V | 0 C |
| `low_temp` | 1.25 V | -40 C |
| `worst_low` | 0.95 V | -40 C |

These values come from each Liberty header. The process scalar is 1.0 in every
file; the corner differences are already characterized in the tables. The
downloader verifies voltage, temperature, operating condition and units, preserves
the original bytes/notices, and records SHA-256s. It also downloads the matching
`Front_End/Verilog/NangateOpenCellLibrary.v` for simulation. The supplied library
was developed by Nangate; its license accompanies the files.

All five Liberty files have the same internal library name. The generated MMMC
setup places each in its own library set and timing condition so their timing
data remains distinct. Both cold corners are included; temperature inversion
means neither a single hot corner nor a single cold corner should be assumed to
dominate every path.

## Configuration and constraints

Edit [config.tcl](config.tcl), or set `FFT_GENUS_CONFIG` to an extra Tcl file that
changes entries in `::fft_syn::cfg` / `::fft_syn::parameters`. For example:

```tcl
set ::fft_syn::cfg(clock_period_ns) 2.0
set ::fft_syn::cfg(output_load_ff) 5.0
set ::fft_syn::parameters(SAMPLES_ADDR_WIDTH) 15
set ::fft_syn::parameters(TWIDDLES_ADDR_WIDTH) 14
```

Defaults match the tested ABFP32 RTL: radix 16, exponent width 6, explicit mantissa
width 25; 15/14 address bits; all arithmetic register flags enabled; read/write
latencies 1; reset depth 1; `LUTX=6`, `GRADE=1`, `II_CYCLES=4`.
`REGSITERED_MULTIPLIER` deliberately keeps the RTL's spelling.
Changing pipeline/format parameters requires matching the later testbench and
rechecking in-place stage dependencies at the selected FFT size. The minimum
launch interval is not a guarantee that every small in-place transform finishes
its previous-stage writes before its next-stage reads. An application requiring
the conservative bound may explicitly raise II; it is not silently raised here.

At II=4, the 11/16/26 RTL regression passed the 32768-point transform, the
eight-block 128-point/1024-sample batch, single 128/64-point cases, a four-block
64-point batch and dense 2-point traffic. Single 4-point and 32-point probes
produced incorrect results because stage reads overtook prior writes; the
request-only RTL has no dependency interlock. Choose runtime schedules supported
by this memory/pipeline configuration. The gate-level tests must retain the same
II=4 setting; a larger interval would not test the synthesized default.

The clock period and interface budgets are explicit in ns, with output load in
fF. Default boundary assumptions are 0.30 ns maximum / 0.05 ns minimum input
delay, 0.30 ns maximum / -0.05 ns minimum output delay (a 0.05 ns external hold
requirement), 0.05 ns input/clock transition, 0.10 ns setup uncertainty, 0.05 ns
hold uncertainty, 5 fF output load, and a 0.20 ns maximum transition constraint.
These are editable initial budgets, not measured external-memory characteristics.
The external controller and memories must meet them at the 500 MHz interface.

`rst_i` is synchronous and also gates output enables. It remains timed, as do
all runtime configuration and memory ports. There are no false paths, tied
configuration inputs or throughput-derived multicycle exceptions. Synthesis
does not request retiming, clock gating or scan insertion, preserving the RTL's
cycle protocol for subsequent comparison.

This is **logical, pre-layout synthesis** using the Liberty wire-load models.
No LEF, floorplan, extracted RC, CTS or routing is provided. Empty RC-corner
objects organize the MMMC views; `interconnect_mode wireload` selects Liberty
wire-load estimation rather than claiming extracted interconnect. SDF and timing
are synthesis estimates. Physical timing and hold closure need a later physical
implementation flow.

## Outputs and timing review

Under `synthesis/genus/runs/abfp32_500mhz/` by default:

| File | Purpose |
| --- | --- |
| `outputs/fft_accelerator.mapped.v` | One structural cell netlist, top `fft_accelerator` |
| `outputs/fft_accelerator.<corner>.sdf` | Five corner-specific pre-layout timing files |
| `outputs/fft_accelerator.constraints.sdc` | Standalone resolved input constraints |
| `outputs/fft_accelerator.mapped.sdc` | Shared functional constraints exported with explicit `view_typical` |
| `outputs/fft_accelerator.mmmc.tcl` | Resolved library/view definitions |
| `reports/<corner>.setup.rpt` / `.hold.rpt` | Worst 20 late/early paths for each view |
| `reports/timing_intent_pre.rpt` / `_post.rpt` | Timing-constraint coverage checks |
| `reports/elaboration.rpt` / `mapped_design.rpt` | Unresolved-reference checks |
| `reports/area.rpt`, `gates.rpt`, `qor.rpt` | Mapping, cell count/area and timing summary |
| `reports/design_rules.rpt` | Electrical design-rule violations |
| `run_config.tcl` | Resolved configuration, parameters, source/library paths |

Successful script completion means outputs were generated. Review the Genus log
for errors/warnings, verify that the design has no unresolved/black-box logic or
unintended latches, check timing coverage and design rules, and inspect setup and
hold slack at **every** corner. A 500 MHz constraint is a target; this script does
not assert that the existing RTL will meet it.

## Handoff for the next gate-level tests

Use the same mapped netlist for every corner. Compile it with the fetched Nangate
Verilog cell model in place of the RTL DUT hierarchy. The mapped module is a
fixed specialization: the RTL testbench's parameterized DUT instantiation must
be adapted to instantiate the netlist without parameter overrides and with the
matching synthesized configuration.

Start with functional GLS, then annotate the chosen `<corner>.sdf` onto that DUT
instance using Questa or another timing-capable simulator. Match the annotation
hierarchy and inspect annotation coverage. The cell model's placeholder delays
are not the selected PVT timing; timing GLS needs its SDF and active specify/
timing checks. Verilator remains useful for functional regression, but is not
the timing-check/SDF sign-off simulator.

At 500 MHz the testbench must drive a 2 ns clock and use fine time precision
(for example, `1ns/1ps`); the current RTL scaffold's `1ns/1ns` precision and
10 ns clock are not suitable for this timing test. Respect min/max interface
delays, sample after propagation settles, and hold reset for the RTL's documented
pipeline hold interval. Datapaths are intentionally unreset, so early X values
must be ignored until their valid controls arrive. Use the existing ABFP golden
models and ECG files with the same format and ordering.

Gate-level TB adaptation and simulation are the next step; this change does not
alter the RTL or the already signed verification file. The Genus script is
prepared for execution on the separate licensed device and has not been run in
Genus here.
