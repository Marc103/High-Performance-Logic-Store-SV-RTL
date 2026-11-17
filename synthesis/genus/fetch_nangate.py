#!/usr/bin/env python3
"""Fetch the requested Nangate NLDM corners and the matching GLS cell model.

Python standard library only. Files retain their original bytes and notices.
The repository revision is pinned so different devices use identical inputs.
"""

import argparse
import hashlib
import json
from pathlib import Path
import re
import urllib.request


REVISION = "6f388c0cd9fb9902dabb6cf977b6208d7fd54c92"
SOURCE = "https://github.com/JulianKemmerer/Drexel-ECEC575"
RAW = (
    "https://raw.githubusercontent.com/JulianKemmerer/Drexel-ECEC575/"
    f"{REVISION}/Encounter/NangateOpenCellLibrary/"
)
CORNERS = {
    "typical": (1.10, 25.0),
    "slow": (0.95, 125.0),
    "fast": (1.25, 0.0),
    "low_temp": (1.25, -40.0),
    "worst_low": (0.95, -40.0),
}


def check_library(data: bytes, corner: str) -> None:
    """Reject wrong corners, error pages, CCS/ECSM files or changed units."""
    text = data.decode("ascii")
    if not re.search(r"library\s*\(\s*NangateOpenCellLibrary\s*\)", text):
        raise ValueError(f"{corner}: not a Nangate Liberty library")
    for field, expected in zip(("nom_voltage", "nom_temperature"), CORNERS[corner]):
        match = re.search(rf"\b{field}\s*:\s*([-+0-9.eE]+)\s*;", text)
        if not match or float(match[1]) != expected:
            raise ValueError(f"{corner}: unexpected {field}; expected {expected}")
    if not re.search(rf"default_operating_conditions\s*:\s*{corner}\s*;", text):
        raise ValueError(f"{corner}: wrong default operating condition")
    if not re.search(r'time_unit\s*:\s*"1ns"\s*;', text):
        raise ValueError(f"{corner}: expected 1 ns Liberty time unit")
    if not re.search(r"capacitive_load_unit\s*\(\s*1\s*,\s*ff\s*\)", text):
        raise ValueError(f"{corner}: expected 1 fF Liberty capacitance unit")
    if "cell_rise" not in text or "output_current_rise" in text:
        raise ValueError(f"{corner}: expected NLDM timing tables")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--destination", type=Path,
        default=Path(__file__).resolve().parent / "libraries/NangateOpenCellLibrary",
        help="Library root (the directory containing Front_End)",
    )
    args = parser.parse_args()
    root = args.destination.resolve()
    files = ["LICENSE", "README", "Front_End/Verilog/NangateOpenCellLibrary.v"]
    files += [f"Front_End/Liberty/NLDM/NangateOpenCellLibrary_{c}.lib" for c in CORNERS]
    downloaded = {}
    # Fetch and validate the complete set before writing any library files.
    for relative in files:
        request = urllib.request.Request(RAW + relative, headers={"User-Agent": "fft-genus-library-fetch"})
        with urllib.request.urlopen(request, timeout=120) as response:
            data = response.read()
        if relative.endswith(".lib"):
            corner = relative.rsplit("/", 1)[-1].removeprefix("NangateOpenCellLibrary_").removesuffix(".lib")
            check_library(data, corner)
        if not data:
            raise ValueError(f"Empty download: {relative}")
        downloaded[relative] = data

    hashes = {name: hashlib.sha256(data).hexdigest() for name, data in downloaded.items()}
    for relative, data in downloaded.items():
        target = root / relative
        # An existing different library must not be overwritten silently.
        if target.exists() and target.read_bytes() != data:
            raise FileExistsError(f"Different existing file: {target}. Choose another --destination.")
    for relative, data in downloaded.items():
        target = root / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
        print(f"{hashes[relative]}  {relative}")
    (root / "source_manifest.json").write_text(
        json.dumps({"repository": SOURCE, "revision": REVISION, "sha256": hashes}, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"Library ready: {root}")


if __name__ == "__main__":
    main()
