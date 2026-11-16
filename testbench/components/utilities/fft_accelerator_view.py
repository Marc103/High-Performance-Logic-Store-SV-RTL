#!/usr/bin/env python3
"""Generate ABFP FFT memories, or display a sample memory and accelerator result.

Words are hexadecimal packed {real, imaginary}, with explicit ABFP mantissas.
Generation uses only the standard library. Viewing needs numpy and matplotlib.
"""
from __future__ import annotations
import argparse
from fractions import Fraction
import hashlib
import json
import math
from pathlib import Path
import re
from urllib.request import urlopen

SAMPLES = 32768
TWIDDLES = 16384
SOURCE = "https://physionet.org/files/mitdb/1.0.0/"
DATASET = "https://physionet.org/content/mitdb/1.0.0/"


def power_of_two(n: int) -> bool:
    return n > 0 and n & (n - 1) == 0


def reverse_bits(index: int, bits: int) -> int:
    result = 0
    for _ in range(bits):
        result = (result << 1) | (index & 1)
        index >>= 1
    return result


def encode(value: Fraction | float, e: int, m: int, base: int) -> int:
    """Exact rational conversion with round-to-nearest-even and canonical zeros."""
    if e < 1 or not power_of_two(base) or base < 2 or m < base.bit_length() - 1:
        raise ValueError("Require exponent bits >=1, power-of-two base >=2, and mantissa >=log2(base)")
    value = Fraction(value)
    sign = int(value < 0)
    sign_word = sign << (e + m)
    if not value:
        return sign_word
    num, den = abs(value).as_integer_ratio()
    exponent = (1 << (e - 1)) - 1
    while num >= den:
        den *= base
        exponent += 1
    while num * base < den:
        num *= base
        exponent -= 1
    quotient, remainder = divmod(num << m, den)
    if 2 * remainder > den or (2 * remainder == den and quotient & 1):
        quotient += 1
    if quotient >= 1 << m:
        quotient >>= base.bit_length() - 1
        exponent += 1
    if exponent <= 0:
        return sign_word
    maximum = (1 << e) - 1
    if exponent > maximum or (exponent == maximum and quotient & (1 << (m - 1))):
        exponent = maximum
        quotient |= 1 << (m - 1)
    return sign_word | (exponent << m) | (quotient & ((1 << m) - 1))


def decode(word: int, e: int, m: int, base: int) -> float:
    sign = -1.0 if word >> (e + m) else 1.0
    exponent = (word >> m) & ((1 << e) - 1)
    mantissa = word & ((1 << m) - 1)
    if exponent == 0:
        if mantissa:
            raise ValueError("Undefined input: exponent zero with nonzero mantissa")
        return math.copysign(0.0, sign)
    if exponent == (1 << e) - 1 and mantissa & (1 << (m - 1)):
        return math.nan  # This format deliberately combines NaN/Inf.
    if mantissa >> (m - (base.bit_length() - 1)) == 0:
        raise ValueError("Undefined input: nonzero exponent with an unnormalized mantissa")
    return sign * mantissa / (1 << m) * base ** (exponent - ((1 << (e - 1)) - 1))


def read_words(path: Path, width: int, expected_depth: int | None = None) -> list[int]:
    result = []
    for line_no, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        line = line.split("//", 1)[0].strip()
        if not line:
            continue
        for token in line.split():
            if not re.fullmatch(r"[0-9a-fA-F]+", token):
                raise ValueError(f"{path}:{line_no}: expected a hexadecimal memory word")
            value = int(token, 16)
            if len(token) > (width + 3) // 4 or value >= 1 << width:
                raise ValueError(f"{path}:{line_no}: word exceeds {width} bits")
            result.append(value)
    if expected_depth is not None and len(result) != expected_depth:
        raise ValueError(f"{path}: expected {expected_depth} entries, found {len(result)}")
    return result


def unpack(words: list[int], e: int, m: int, base: int):
    import numpy as np
    width = 1 + e + m
    mask = (1 << width) - 1
    return np.array([complex(decode(x >> width, e, m, base), decode(x & mask, e, m, base)) for x in words])


def write_words(path: Path, words: list[int], width: int, metadata: dict) -> None:
    path.write_text("".join(f"{x:0{(width + 3) // 4}x}\n" for x in words), encoding="ascii", newline="\n")
    metadata = dict(metadata, sha256=hashlib.sha256(path.read_bytes()).hexdigest())
    Path(str(path) + ".json").write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8", newline="\n")


def generate(args) -> None:
    dest = args.output_dir
    dest.mkdir(parents=True, exist_ok=True)
    e, m, base = args.exponent_width, args.mantissa_width, args.base
    width = 1 + e + m
    if args.synthetic:
        fs = 360
        data = []
        for i in range(2 * SAMPLES):
            t = i / fs
            phase = (t % 0.83) / 0.83
            value = (1.1 * math.exp(-((phase - 0.25) / 0.012) ** 2)
                     - 0.25 * math.exp(-((phase - 0.23) / 0.015) ** 2)
                     + 0.18 * math.exp(-((phase - 0.53) / 0.08) ** 2)
                     + 0.06 * math.sin(2 * math.pi * 0.2 * t))
            data.append(Fraction(value))
        provenance = {"kind": "synthetic", "description": "Deterministic ECG-like pulse train; not a real recording"}
    else:
        def source_bytes(name):
            if args.wfdb_dir is not None:
                return (args.wfdb_dir / name).read_bytes()
            with urlopen(SOURCE + name, timeout=60) as response:
                return response.read()
        header = source_bytes("100.hea")
        raw = source_bytes("100.dat")
        rows = header.decode("ascii").splitlines()
        first = rows[0].split()
        fields = rows[1].split()
        if first[1] != "2" or fields[1] != "212":
            raise ValueError("This generator expects record 100's two-channel WFDB 212 format")
        fs = float(first[2])
        gain = int(fields[2])
        baseline = int(fields[4])
        data = []
        for i in range(0, len(raw), 3):
            adc = raw[i] | ((raw[i + 1] & 15) << 8)
            if adc & 2048:
                adc -= 4096
            data.append(Fraction(adc - baseline, gain))
        if data[0] != Fraction(int(fields[5]) - baseline, gain):
            raise ValueError("WFDB decode does not match the header's initial sample")
        if len(data) < 2 * SAMPLES:
            raise ValueError("Source ECG is too short for the two requested fixture windows")
        provenance = {
            "kind": "real ECG", "dataset": "MIT-BIH Arrhythmia Database v1.0.0", "record": "100",
            "channel": fields[-1], "units": "mV", "adc_gain": gain, "adc_zero": baseline,
            "dataset_url": DATASET, "source_urls": [SOURCE + "100.hea", SOURCE + "100.dat"],
            "license": "Open Data Commons Attribution License v1.0",
            "license_url": "https://opendatacommons.org/licenses/by/1-0/",
            "citation": "Moody G, Mark R. MIT-BIH Arrhythmia Database (version 1.0.0). PhysioNet, 2005. doi:10.13026/C2F305",
            "raw_sha256": hashlib.sha256(raw).hexdigest(), "header": header.decode("ascii"),
            "processing": "First channel; subtract ADC zero and divide by gain. No filtering, detrending, or amplitude normalization.",
        }
    for number in range(2):
        natural = data[number * SAMPLES:(number + 1) * SAMPLES]
        words = [encode(natural[reverse_bits(i, 15)], e, m, base) << width for i in range(SAMPLES)]
        path = dest / f"{e}_{m}_samples_{number}.txt"
        write_words(path, words, 2 * width, dict(provenance, base=base, exponent_width=e, mantissa_width=m,
            depth=SAMPLES, sample_order="bit_reversed", sample_order_points=SAMPLES,
            sample_rate_hz=fs, start_sample=number * SAMPLES, imaginary_component=0))
        print(path)
    roots = []
    for k in range(TWIDDLES):
        re_value = math.cos(-2 * math.pi * k / SAMPLES)
        im_value = math.sin(-2 * math.pi * k / SAMPLES)
        if abs(re_value) < 1e-15:
            re_value = 0.0
        if abs(im_value) < 1e-15:
            im_value = 0.0
        roots.append((encode(re_value, e, m, base) << width) | encode(im_value, e, m, base))
    path = dest / f"{e}_{m}_twiddles_0.txt"
    write_words(path, roots, 2 * width, dict(base=base, exponent_width=e, mantissa_width=m,
        depth=TWIDDLES, twiddle_points=SAMPLES, sample_order="natural k", definition="exp(-j*2*pi*k/32768)"))
    print(path)


def view_all_blocks(args, natural, results, points, count, fs, units) -> None:
    import numpy as np
    import matplotlib.pyplot as plt
    total = points * count
    if total > len(natural) or (results is not None and total > len(results)):
        raise ValueError("FFT batch exceeds the memory image")
    signals = natural[:total].reshape(count, points)
    reference = np.fft.fft(signals, axis=1)
    hardware = results[:total].reshape(count, points) if results is not None else None
    rows = 3 if hardware is not None else 2
    fig, axes = plt.subplots(rows, 1, figsize=(13, 3.3 * rows), constrained_layout=True)
    fig.suptitle(f"{count} independent {points}-point FFTs — {total} ECG samples")
    times = np.arange(total) / fs
    axes[0].plot(times, signals.ravel().real, label="ECG real", linewidth=0.9)
    if np.any(signals.imag):
        axes[0].plot(times, signals.ravel().imag, label="Imaginary", linewidth=0.8)
    for block in range(count):
        if block:
            axes[0].axvline(block * points / fs, color="gray", alpha=0.35, linewidth=0.7)
        axes[0].text((block + 0.5) * points / fs, 0.98, f"Block {block + 1}",
                     transform=axes[0].get_xaxis_transform(), ha="center", va="top", fontsize=8)
    axes[0].set(xlabel="Time (s)", ylabel=units, title="Input in natural time order; vertical lines mark FFT blocks")
    axes[0].legend(loc="lower right")
    bins = np.arange(1 if args.exclude_dc else 0, points // 2 + 1)
    frequencies = bins * fs / points
    for block in range(count):
        color = plt.get_cmap("tab10")(block % 10)
        axes[1].plot(frequencies, np.abs(reference[block, bins]), color=color, linewidth=0.9,
                     label=f"Block {block + 1}")
        if hardware is not None:
            axes[1].plot(frequencies, np.abs(hardware[block, bins]), color=color, linestyle="--", linewidth=1.0)
            axes[2].plot(frequencies, np.abs(hardware[block, bins] - reference[block, bins]),
                         color=color, linewidth=0.9)
    title = "Forward FFTs: solid = NumPy, dashed = ABFP" if hardware is not None else "Forward FFTs"
    if args.exclude_dc:
        title += " (DC bins excluded)"
    axes[1].set(xlabel="Frequency (Hz)", ylabel="Unnormalized magnitude", title=title)
    axes[1].legend(ncol=min(count, 4), fontsize=8)
    if hardware is not None:
        error = np.abs(hardware - reference)
        relative = np.linalg.norm(hardware - reference) / max(np.linalg.norm(reference), np.finfo(float).tiny)
        axes[2].set(xlabel="Frequency (Hz)", ylabel="Absolute error", title="Complex-bin error for each block; colors match spectra")
        print(f"{count} x {points}-point FFTs, {total} samples, max absolute error={error.max():.9g}, relative L2 error={relative:.9g}")
    for axis in axes:
        axis.grid(alpha=0.25)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        fig.savefig(args.output, dpi=160)
        print(args.output)
    else:
        plt.show()


def view(args) -> None:
    import numpy as np
    import matplotlib
    if args.output:
        matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    metadata = {}
    if args.result and Path(str(args.result) + ".json").exists():
        metadata = json.loads(Path(str(args.result) + ".json").read_text(encoding="utf-8"))
    sample_meta_path = Path(str(args.samples) + ".json")
    sample_meta = json.loads(sample_meta_path.read_text(encoding="utf-8")) if sample_meta_path.exists() else {}
    match = re.match(r"(\d+)_(\d+)_", args.samples.name)
    e = args.exponent_width or metadata.get("exponent_width", int(match[1]) if match else 6)
    m = args.mantissa_width or metadata.get("mantissa_width", int(match[2]) if match else 25)
    base = args.base or metadata.get("base", sample_meta.get("base", 16))
    points = args.points or metadata.get("fft_points", SAMPLES)
    count = metadata.get("fft_count", 1)
    order_points = args.sample_order_points or metadata.get("sample_order_points", sample_meta.get("sample_order_points", SAMPLES))
    fs = args.sample_rate or sample_meta.get("sample_rate_hz", 360.0)
    if not power_of_two(points) or points > SAMPLES or not power_of_two(order_points) or SAMPLES % order_points:
        raise ValueError("FFT size and sample-order block size must be powers of two dividing 32768")
    if args.block < 0 or args.block >= count:
        raise ValueError(f"Block must be in 0..{count - 1}")
    stored = unpack(read_words(args.samples, 2 * (1 + e + m), SAMPLES), e, m, base)
    natural = np.empty_like(stored)
    bits = order_points.bit_length() - 1
    for i in range(len(stored)):
        natural[i] = stored[(i // order_points) * order_points + reverse_bits(i % order_points, bits)]
    all_results = unpack(read_words(args.result, 2 * (1 + e + m), SAMPLES), e, m, base) if args.result else None
    if args.all_blocks:
        view_all_blocks(args, natural, all_results, points, count, fs, sample_meta.get("units", "Amplitude"))
        return
    offset = args.block * points
    signal = natural[offset:offset + points]
    reference = np.fft.fft(signal)
    result = all_results[offset:offset + points] if all_results is not None else None
    rows = 3 if result is not None else 2
    fig, axes = plt.subplots(rows, 1, figsize=(12, 3 * rows), constrained_layout=True)
    times = np.arange(points) / fs
    axes[0].plot(times, signal.real, label="ECG real", linewidth=0.8)
    if np.any(signal.imag):
        axes[0].plot(times, signal.imag, label="Imaginary", linewidth=0.8)
    axes[0].set(xlabel="Time (s)", ylabel=sample_meta.get("units", "Amplitude"), title="Input in natural time order")
    axes[0].legend()
    bins = np.arange(1 if args.exclude_dc else 0, points // 2 + 1)
    frequencies = bins * fs / points
    axes[1].plot(frequencies, np.abs(reference[bins]), label="NumPy reference", linewidth=0.9)
    if result is not None:
        axes[1].plot(frequencies, np.abs(result[bins]), label="ABFP accelerator", linewidth=0.8, alpha=0.8)
        error = np.abs(result - reference)
        axes[2].plot(frequencies, error[bins], linewidth=0.8)
        axes[2].set(xlabel="Frequency (Hz)", ylabel="Absolute error", title="ABFP result versus floating-point FFT")
        relative = np.linalg.norm(result - reference) / max(np.linalg.norm(reference), np.finfo(float).tiny)
        print(f"N={points}, max absolute error={error.max():.9g}, relative L2 error={relative:.9g}")
    spectrum_title = "Forward FFT (DC bin excluded)" if args.exclude_dc else "Forward FFT"
    axes[1].set(xlabel="Frequency (Hz)", ylabel="Unnormalized magnitude", title=spectrum_title)
    axes[1].legend()
    for axis in axes:
        axis.grid(alpha=0.25)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        fig.savefig(args.output, dpi=160)
        print(args.output)
    else:
        plt.show()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    gen = commands.add_parser("generate", help="Generate fixed-depth ECG/sample and twiddle files")
    gen.add_argument("--output-dir", type=Path, required=True)
    gen.add_argument("--wfdb-dir", type=Path, help="Read downloaded record 100.hea/100.dat from this directory")
    gen.add_argument("--synthetic", action="store_true", help="Explicitly generate synthetic ECG-like data")
    gen.add_argument("--exponent-width", type=int, default=6)
    gen.add_argument("--mantissa-width", type=int, default=25)
    gen.add_argument("--base", type=int, default=16)
    gen.set_defaults(func=generate)
    display = commands.add_parser("view", help="Display input samples and an optional accelerator result")
    display.add_argument("--samples", type=Path, required=True)
    display.add_argument("--result", type=Path)
    display.add_argument("--output", type=Path, help="Save a plot instead of opening an interactive window")
    display.add_argument("--exclude-dc", action="store_true", help="Show only frequencies >0 Hz in the spectrum and error panels")
    display.add_argument("--points", type=int)
    blocks = display.add_mutually_exclusive_group()
    blocks.add_argument("--block", type=int, default=0)
    blocks.add_argument("--all-blocks", action="store_true", help="Show the entire input batch and each block's spectrum/error")
    display.add_argument("--sample-order-points", type=int)
    display.add_argument("--sample-rate", type=float)
    display.add_argument("--exponent-width", type=int)
    display.add_argument("--mantissa-width", type=int)
    display.add_argument("--base", type=int)
    display.set_defaults(func=view)
    args = parser.parse_args()
    try:
        args.func(args)
    except (ValueError, OSError, ImportError) as exc:
        parser.exit(1, f"error: {exc}\n")


if __name__ == "__main__":
    main()
