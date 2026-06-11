#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SIM_DIR="$SCRIPT_DIR/simulate_verilator"

TOP_MODULE="multistage_fanout_tb"
THREADS="${THREADS:-1}"

TB_DIR="$REPO_ROOT/testbench"
CT_DIR="$TB_DIR/components"
RTL_DIR="$REPO_ROOT/rtl"

if ! [[ "$THREADS" =~ ^[1-9][0-9]*$ ]]; then
    echo "error: THREADS must be a positive integer" >&2
    exit 1
fi

if ! command -v verilator >/dev/null 2>&1; then
    echo "error: verilator was not found in PATH" >&2
    exit 1
fi

VERILATOR_VERSION="$(verilator --version | awk '{print $2}')"
VERILATOR_MAJOR="${VERILATOR_VERSION%%.*}"

if [ "$VERILATOR_MAJOR" -lt 5 ]; then
    cat >&2 <<EOF
error: Verilator $VERILATOR_VERSION is installed, but this script expects Verilator 5.x or newer.

This testbench uses a SystemVerilog testbench style with delays, classes, fork/join_none,
and VCD dumping. Verilator 5.x's --binary + --timing flow is the practical starting point.
EOF
    exit 1
fi

if [ -z "${CXX:-}" ]; then
    if command -v g++-11 >/dev/null 2>&1; then
        export CXX="g++-11"
    elif command -v g++-10 >/dev/null 2>&1; then
        export CXX="g++-10"
    fi
fi

CXX="${CXX:-g++}"
export CXX

if ! command -v "$CXX" >/dev/null 2>&1; then
    echo "error: C++ compiler '$CXX' was not found in PATH" >&2
    exit 1
fi

COROUTINE_CFLAGS=""
if ! echo '#include <coroutine>' | "$CXX" -std=c++20 -x c++ -fsyntax-only - >/dev/null 2>&1; then
    if echo '#include <coroutine>' | "$CXX" -std=c++20 -fcoroutines -x c++ -fsyntax-only - >/dev/null 2>&1; then
        COROUTINE_CFLAGS="-fcoroutines"
    else
    cat >&2 <<EOF
error: C++ compiler '$CXX' cannot compile #include <coroutine>.

Verilator $VERILATOR_VERSION uses C++20 coroutine support for --timing.
Install a newer compiler in WSL, then rerun this script:

    sudo apt update
    sudo apt install -y g++-11
    CXX=g++-11 ./simulate_verilator.sh

Current compiler:
$("$CXX" --version | head -n 1)
EOF
        exit 1
    fi
fi

rm -rf "$SIM_DIR"
mkdir -p "$SIM_DIR"
cd "$SIM_DIR"

verilator \
    -sv \
    --binary \
    --timing \
    --trace-vcd \
    --threads "$THREADS" \
    -CFLAGS "$COROUTINE_CFLAGS" \
    -MAKEFLAGS "CXX=$CXX" \
    --top-module "$TOP_MODULE" \
    -Wall \
    -Wno-fatal \
    -I"$RTL_DIR" \
    -I"$TB_DIR" \
    -I"$CT_DIR/drivers" \
    -I"$CT_DIR/generators" \
    -I"$CT_DIR/golden_models" \
    -I"$CT_DIR/interfaces" \
    -I"$CT_DIR/monitors" \
    -I"$CT_DIR/package_manager" \
    -I"$CT_DIR/scoreboards" \
    -I"$CT_DIR/io" \
    -I"$CT_DIR/utilities" \
    "$SCRIPT_DIR/${TOP_MODULE}.sv"

"$SIM_DIR/obj_dir/V$TOP_MODULE"
