@echo off

REM -------------------------------------------------
REM Optional: Set ModelSim path if NOT in system PATH
REM (Uncomment and adjust if needed)
REM -------------------------------------------------
REM set MODELSIM=C:\questasim64\win64
REM set PATH=%MODELSIM%;%PATH%

REM -------------------------------------------------
REM Clean + setup simulation directory
REM -------------------------------------------------
rmdir /s /q simulate 2>nul
mkdir simulate
cd simulate

vlib work

REM Parameter defaults. Override with "set NAME=value" before calling this script.
if not defined REGISTERED_IN set REGISTERED_IN=1
if not defined DATA_WIDTH set DATA_WIDTH=8
if not defined INGRESS_SIZE set INGRESS_SIZE=2
if not defined EGRESS_SIZE set EGRESS_SIZE=8

REM -------------------------------------------------
REM Directories
REM -------------------------------------------------
set TB_DIR=..\..\testbench
set CT_DIR=..\..\components
set RTL_DIR=..\..\..\rtl
set TP_DIR=..\..\third-party

REM -------------------------------------------------
REM Include directory flags
REM -------------------------------------------------
set INCLUDE_FLAGS=^
-incdir %RTL_DIR% ^
-incdir %TB_DIR% ^
-incdir %TP_DIR% ^
-incdir %CT_DIR%\drivers ^
-incdir %CT_DIR%\generators ^
-incdir %CT_DIR%\golden_models ^
-incdir %CT_DIR%\interfaces ^
-incdir %CT_DIR%\monitors ^
-incdir %CT_DIR%\package_manager ^
-incdir %CT_DIR%\scoreboards ^
-incdir %CT_DIR%\io ^
-incdir %CT_DIR%\utilities

REM -------------------------------------------------
REM Compile (SystemVerilog)
REM -------------------------------------------------
vlog %INCLUDE_FLAGS% -sv ..\packer_tb.sv

IF ERRORLEVEL 1 (
    echo Compilation failed.
    cd ..
    exit /b 1
)

REM -------------------------------------------------
REM Run simulation (command line mode)
REM -------------------------------------------------
vsim -voptargs=+acc -c ^
    -g/packer_tb/REGISTERED_IN=%REGISTERED_IN% ^
    -g/packer_tb/DATA_WIDTH=%DATA_WIDTH% ^
    -g/packer_tb/INGRESS_SIZE=%INGRESS_SIZE% ^
    -g/packer_tb/EGRESS_SIZE=%EGRESS_SIZE% ^
    packer_tb ^
    -do "vcd file waves.vcd; vcd add -r /*; run -all; vcd flush; quit -f" ^
    %*
cd ..
