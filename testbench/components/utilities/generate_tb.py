#!/usr/bin/env python3
"""
Generate/remove a testbench component scaffold from the AA templates.

Place this file in:
    testbench/components/utilities/generate_template_component.py
"""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class TemplateJob:
    template: Path
    output: Path
    kind: str
    package_file: Path | None = None


def camel_to_snake(name: str) -> str:
    s1 = re.sub(r"(.)([A-Z][a-z]+)", r"\1_\2", name)
    s2 = re.sub(r"([a-z0-9])([A-Z])", r"\1_\2", s1)
    return s2.lower()


def render_template(text: str, base: str, snake: str, kind: str) -> str:
    upper_snake = snake.upper()

    replacements = {
        "???_inf": f"{snake}_inf",
        "???_tb": f"{snake}_tb",
        '"???.sv"': f'"{snake}.sv"',
        "`???_IO_IN_STRUCT": f"`{upper_snake}_IO_IN_STRUCT",
        "`???_IO_OUT_STRUCT": f"`{upper_snake}_IO_OUT_STRUCT",
        "???Generator": f"{base}Generator",
        "???Driver": f"{base}Driver",
        "???Monitor": f"{base}Monitor",
        "???Model": f"{base}Model",
        "???Scoreboard": f"{base}Scoreboard",
        "???IO": f"{base}IO",
    }

    for old, new in replacements.items():
        text = text.replace(old, new)

    text = text.replace("???_io_in_t", f"{snake}_io_in_t")
    text = text.replace("???_io_out_t", f"{snake}_io_out_t")
    text = text.replace("???_io_in_q", f"{snake}_io_in_q")
    text = text.replace("???_io_out_q", f"{snake}_io_out_q")
    text = text.replace("???_io_in", f"{snake}_io_in")
    text = text.replace("???_io_out", f"{snake}_io_out")
    text = text.replace("???_out_l", f"{snake}_out_l")

    return text


def find_testbench_dir(script_path: Path) -> Path:
    utilities_dir = script_path.resolve().parent
    components_dir = utilities_dir.parent
    testbench_dir = components_dir.parent

    if components_dir.name != "components":
        raise RuntimeError(
            "This script should be placed in testbench/components/utilities. "
            f"I inferred components_dir={components_dir}"
        )

    return testbench_dir


def package_include_line(filename: str) -> str:
    return f'    `include "{filename}"\n'


def include_already_present(pkg_text: str, filename: str) -> bool:
    pattern = rf'(?m)^\s*`include\s+"{re.escape(filename)}"\s*$'
    return re.search(pattern, pkg_text) is not None


def insert_include_before_endpackage(pkg_text: str, include_line: str) -> str:
    filename_match = re.search(r'"([^"]+)"', include_line)
    filename = filename_match.group(1) if filename_match else include_line.strip()

    if include_already_present(pkg_text, filename):
        return pkg_text

    match = re.search(r"(?m)^\s*endpackage\s*$", pkg_text)
    if not match:
        raise RuntimeError("Could not find an endpackage line.")

    insert_at = match.start()
    prefix = pkg_text[:insert_at]
    suffix = pkg_text[insert_at:]

    if prefix and not prefix.endswith("\n"):
        prefix += "\n"

    return prefix + include_line + suffix


def remove_include_line(pkg_text: str, filename: str) -> str:
    pattern = rf'(?m)^\s*`include\s+"{re.escape(filename)}"\s*\n?'
    return re.sub(pattern, "", pkg_text)


def remove_empty_parents(paths: list[Path], stop_dir: Path) -> list[Path]:
    removed: list[Path] = []

    for path in paths:
        parent = path.parent

        while parent != stop_dir and stop_dir in parent.parents:
            try:
                parent.rmdir()
                removed.append(parent)
            except OSError:
                break

            parent = parent.parent

    return removed


def write_text_no_newline_translation(path: Path, text: str) -> None:
    with path.open("w", encoding="utf-8", newline="") as file:
        file.write(text)


def build_jobs(tb_dir: Path, base: str, snake: str) -> list[TemplateJob]:
    comp = tb_dir / "components"
    pm = comp / "package_manager"

    jobs = [
        TemplateJob(comp / "generators" / "AATemplateGenerator.sv", comp / "generators" / f"{base}Generator.sv", "generator", pm / "generators_pkg.svh"),
        TemplateJob(comp / "drivers" / "AATemplateDriver.sv", comp / "drivers" / f"{base}Driver.sv", "driver", pm / "drivers_pkg.svh"),
        TemplateJob(comp / "golden_models" / "AATemplateModel.sv", comp / "golden_models" / f"{base}Model.sv", "model", pm / "golden_models_pkg.svh"),
        TemplateJob(comp / "monitors" / "AATemplateMonitor.sv", comp / "monitors" / f"{base}Monitor.sv", "monitor", pm / "monitors_pkg.svh"),
        TemplateJob(comp / "scoreboards" / "AATemplateScoreboard.sv", comp / "scoreboards" / f"{base}Scoreboard.sv", "scoreboard", pm / "scoreboards_pkg.svh"),
        TemplateJob(comp / "io" / "AATemplateIO.sv", comp / "io" / f"{base}IO.sv", "io", pm / "io_pkg.svh"),
        TemplateJob(tb_dir / "aa_template_tb" / "aa_template_tb.sv", tb_dir / f"{snake}_tb" / f"{snake}_tb.sv", "tb", None),
        TemplateJob(tb_dir / "aa_template_tb" / "simulate.bat", tb_dir / f"{snake}_tb" / "simulate.bat", "simulate", None),
        TemplateJob(tb_dir / "aa_template_tb" / "simulate_verilator.sh", tb_dir / f"{snake}_tb" / "simulate_verilator.sh", "simulate_verilator", None),
    ]

    for candidate in [
        comp / "interfaces" / "aa_template_inf.svh",
        comp / "interfaces" / "AATemplate_inf.svh",
        comp / "interfaces" / "AATemplateInterface.svh",
    ]:
        if candidate.exists():
            jobs.append(
                TemplateJob(
                    candidate,
                    comp / "interfaces" / f"{snake}_inf.svh",
                    "interface",
                    None,
                )
            )
            break

    return jobs


def validate_base_name(base: str) -> bool:
    return re.fullmatch(r"[A-Z][A-Za-z0-9]*", base) is not None


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Generate/remove AA testbench scaffold files."
    )
    parser.add_argument("name", help="CamelCase base name, e.g. MultistageFanout")

    mode = parser.add_mutually_exclusive_group()
    mode.add_argument(
        "--overwrite",
        action="store_true",
        help="Overwrite existing generated files and ensure package includes exist.",
    )
    mode.add_argument(
        "--remove",
        action="store_true",
        help="Remove generated files and remove their package includes.",
    )

    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print what would be created/edited/removed, but do not write anything.",
    )

    args = parser.parse_args()

    base = args.name.strip()

    if not validate_base_name(base):
        print("ERROR: name should be CamelCase, e.g. MultistageFanout", file=sys.stderr)
        return 2

    snake = camel_to_snake(base)
    script_path = Path(__file__)

    try:
        tb_dir = find_testbench_dir(script_path)
    except RuntimeError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2

    jobs = build_jobs(tb_dir, base, snake)

    if args.remove:
        return remove_scaffold(jobs, tb_dir, base, snake, args.dry_run)

    return generate_scaffold(jobs, base, snake, args.overwrite, args.dry_run)


def remove_scaffold(
    jobs: list[TemplateJob],
    tb_dir: Path,
    base: str,
    snake: str,
    dry_run: bool,
) -> int:
    errors: list[str] = []

    for job in jobs:
        if job.package_file is not None and not job.package_file.exists():
            errors.append(f"Missing package file: {job.package_file}")

    if errors:
        print("CANCELLED: no files were removed or edited.", file=sys.stderr)
        for err in errors:
            print(f"- {err}", file=sys.stderr)
        return 1

    existing_outputs = [job.output for job in jobs if job.output.exists()]
    package_updates: dict[Path, str] = {}

    for job in jobs:
        if job.package_file is not None:
            current = package_updates.get(job.package_file)

            if current is None:
                current = job.package_file.read_text(encoding="utf-8")

            current = remove_include_line(current, job.output.name)
            package_updates[job.package_file] = current

    if dry_run:
        print(f"Would remove scaffold for {base} ({snake})")

        print("\nFiles to remove:")
        if existing_outputs:
            for path in existing_outputs:
                print(f"  {path}")
        else:
            print("  <none found>")

        print("\nPackage files to edit:")
        for path in package_updates:
            print(f"  {path}")

        return 0

    for path in existing_outputs:
        path.unlink()

    removed_dirs = remove_empty_parents(existing_outputs, tb_dir)

    for path, text in package_updates.items():
        write_text_no_newline_translation(path, text)

    print(f"Removed scaffold for {base} ({snake}).")

    print("Removed files:")
    if existing_outputs:
        for path in existing_outputs:
            print(f"  {path}")
    else:
        print("  <none found>")

    if removed_dirs:
        print("Removed empty directories:")
        for path in removed_dirs:
            print(f"  {path}")

    print("Updated packages:")
    for path in package_updates:
        print(f"  {path}")

    return 0


def generate_scaffold(
    jobs: list[TemplateJob],
    base: str,
    snake: str,
    overwrite: bool,
    dry_run: bool,
) -> int:
    errors: list[str] = []

    for job in jobs:
        if not job.template.exists():
            errors.append(f"Missing template: {job.template}")

        if job.output.exists() and not overwrite:
            errors.append(f"Output already exists: {job.output}")

        if job.package_file is not None and not job.package_file.exists():
            errors.append(f"Missing package file: {job.package_file}")

    if errors:
        print("CANCELLED: no files were created or edited.", file=sys.stderr)
        for err in errors:
            print(f"- {err}", file=sys.stderr)
        return 1

    rendered_outputs: dict[Path, str] = {}
    package_updates: dict[Path, str] = {}

    try:
        for job in jobs:
            text = job.template.read_text(encoding="utf-8")
            rendered_outputs[job.output] = render_template(text, base, snake, job.kind)

            if job.package_file is not None:
                current = package_updates.get(job.package_file)

                if current is None:
                    current = job.package_file.read_text(encoding="utf-8")

                current = insert_include_before_endpackage(
                    current,
                    package_include_line(job.output.name),
                )

                package_updates[job.package_file] = current

    except RuntimeError as exc:
        print("CANCELLED: no files were created or edited.", file=sys.stderr)
        print(f"- {exc}", file=sys.stderr)
        return 1

    if dry_run:
        action = "overwrite/create" if overwrite else "generate"
        print(f"Would {action} scaffold for {base} ({snake})")

        print("\nFiles to write:")
        for path in rendered_outputs:
            status = "overwrite" if path.exists() else "create"
            print(f"  [{status}] {path}")

        print("\nPackage files to edit:")
        for path in package_updates:
            print(f"  {path}")

        return 0

    for path, text in rendered_outputs.items():
        path.parent.mkdir(parents=True, exist_ok=True)
        write_text_no_newline_translation(path, text)

    for path, text in package_updates.items():
        write_text_no_newline_translation(path, text)

    action = "Generated/overwrote" if overwrite else "Generated"
    print(f"{action} scaffold for {base} ({snake}).")

    print("Wrote:")
    for path in rendered_outputs:
        print(f"  {path}")

    print("Updated packages:")
    for path in package_updates:
        print(f"  {path}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
