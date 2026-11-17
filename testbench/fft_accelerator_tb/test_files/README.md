# FFT accelerator memory files

The checked-in fixtures use **BASE=16**, 6 exponent bits and 25 explicit mantissa
bits: one ABFP32 real component and one ABFP32 imaginary component per memory
word. This is not IEEE binary32. Every row is one 16-digit hexadecimal word,
packed as `{real[31:0], imaginary[31:0]}`, for `$readmemh`-style loading.

* `6_25_samples_0.txt`: 32,768 samples from MIT-BIH record 100, MLII channel,
  source samples 0–32767, converted to mV, imaginary component zero.
* `6_25_samples_1.txt`: the next 32,768 source samples from the same recording.
* `6_25_twiddles_0.txt`: 16,384 coefficients `exp(-j*2*pi*k/32768)` in natural
  **k order**. The reader generates k directly; twiddles must not be bit-reversed.

Sample memories are bit-reversed over a 32,768-point block. The loader restores
natural sample indices and then bit-reverses each selected runtime FFT block.
For smaller FFTs it selects twiddle `k*(32768/N)` from the source table. Therefore
the same files support power-of-two sizes from 2 through 32,768, with positive
`FFT_COUNT` satisfying `N*FFT_COUNT <= 32768` and the configured address widths.
The memory files always retain their fixed 32K/16K depths.

## Provenance

Real ECG data comes from the [MIT-BIH Arrhythmia Database v1.0.0](https://physionet.org/content/mitdb/1.0.0/),
record 100, sampled at 360 Hz. WFDB format 212 is decoded, ADC zero 1024 is
subtracted, and values are divided by the gain of 200 ADC units/mV. No filtering,
detrending, or amplitude normalization is applied. Every fixture has a `.txt.json`
sidecar recording its format, ordering, source URLs and SHA-256 hashes.

Data attribution: Moody, G., and Mark, R. (2005). *MIT-BIH Arrhythmia Database
(version 1.0.0).* PhysioNet. [doi:10.13026/C2F305](https://doi.org/10.13026/C2F305).
Original publication: Moody GB, Mark RG. *The impact of the MIT-BIH Arrhythmia
Database.* IEEE Engineering in Medicine and Biology 20(3):45–50, 2001.
The source data is licensed under the
[Open Data Commons Attribution License v1.0](https://opendatacommons.org/licenses/by/1-0/).

## Select files and run

From this testbench directory in WSL:

```bash
bash simulate_verilator.sh +SAMPLES_FILE=6_25_samples_0.txt \
  +TWIDDLES_FILE=6_25_twiddles_0.txt +FFT_POINTS=32768 \
  +RESULT_FILE=6_25_result_0.txt
```

Compilation parameters use Verilator `-GNAME=value`. Runtime plusargs beginning
with `+` go to the simulation. The default arithmetic format is ABFP32 and the
default interval is the RTL's minimum `II_CYCLES=4`. The testbench exercises that
interval and compares every result against the independent exact model. In-place
stage dependencies still depend on FFT size and memory latency; a small transform
can read stale results before a prior stage writes back. `WRITE_COMMIT_LATENCY`
is a conservative sufficient interval, not the minimum supported launch interval.
Use `-GII_CYCLES=47` to reproduce the original conservative ABFP32 runs.

The 11/16/26 minimum-interval regression passed at N=32768,count=1;
N=128,count=1/8; N=64,count=1/4; and N=2,count=32, using the default pipelines
and memory latencies. Questa's N=128 smoke also passed at II=4. Single N=4 and
N=32 probes failed because next-stage reads precede previous-stage writeback;
those are actual incorrect in-place results for that schedule. See
`../simulate_regression_logs/ii4_results.json` for the passing and failing cases.

After compilation, run another size/file without rebuilding:

```bash
(cd simulate_verilator && ./obj_dir/Vfft_accelerator_tb \
  +SAMPLES_FILE=6_25_samples_1.txt +TWIDDLES_FILE=6_25_twiddles_0.txt \
  +FFT_POINTS=1024 +FFT_COUNT=1 +RESULT_FILE=6_25_result_1024.txt)
```

For Questa, from a shell with Questa in PATH:

```bat
simulate.bat +SAMPLES_FILE=6_25_samples_0.txt +TWIDDLES_FILE=6_25_twiddles_0.txt +FFT_POINTS=128 +RESULT_FILE=6_25_result_questa128.txt
```

Bare filenames resolve under `test_files` and `result_files`. Explicit paths are
also accepted. `+TEST_FILES_DIR=...` and `+RESULT_DIR=...` override those directories;
the result directory must exist. `+SAMPLE_ORDER_POINTS=...` describes custom files
bit-reversed in smaller blocks; `+TWIDDLE_POINTS=...` describes a custom source
twiddle table. Defaults for both are 32768. `+SAMPLE_RATE_HZ=...` sets result metadata.

The scoreboard checks every read address/deadline, every result write and memory
commit, final completion, and all 32K final memory words against the existing
exact ABFP arithmetic models. It saves a complete 32K result memory and a JSON
sidecar with N, count, ordering, filenames and verification status. Only the first
`N*FFT_COUNT` words are transformed; remaining words are unchanged.
For smaller N, "unchanged" refers to the loaded memory image after block
reordering, rather than the original file's 32K bit-reversal permutation. The
viewer selects only transformed blocks using the result metadata.

Wave dumps are disabled by default. Use `TRACE=1` and `+DUMP_WAVES` when needed;
a full 32K run can produce a very large waveform file.

## Display input and result

From the repository root (requires NumPy and Matplotlib):

```bash
python testbench/components/utilities/fft_accelerator_view.py view \
  --samples testbench/fft_accelerator_tb/test_files/6_25_samples_0.txt \
  --result testbench/fft_accelerator_tb/result_files/6_25_result_0.txt
```

Use `--output path/to/plot.png` for a headless plot, `--block 1` to select another
FFT in a batch, or omit `--result` to inspect the input alone. The viewer restores
natural input order, displays the waveform and spectrum, and compares results
with a floating-point NumPy FFT. SV bit-exact verification remains the pass/fail
reference; floating-point error metrics are supplementary.
Add `--exclude-dc` to show only frequencies above 0 Hz in the spectrum and error
panels. This hides the DC bin without changing the input or stored FFT result.
For batched runs, `--all-blocks` shows the complete processed waveform with block
boundaries and overlays each block's spectrum and error using matching colors.

Regenerate the fixtures using the same utility:

```bash
python testbench/components/utilities/fft_accelerator_view.py generate \
  --output-dir testbench/fft_accelerator_tb/test_files
```

This downloads public record 100. `--wfdb-dir DIR` uses an existing `100.hea` and
`100.dat`. `--synthetic` explicitly creates a deterministic synthetic waveform
instead; its metadata labels it as synthetic. `--base`, `--exponent-width` and
`--mantissa-width` generate other ABFP formats using round-to-nearest-even.
