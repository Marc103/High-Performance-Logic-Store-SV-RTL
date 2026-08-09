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

REM -------------------------------------------------
REM Directories
REM -------------------------------------------------
set TB_DIR=..\..\testbench
set CT_DIR=..\..\components
set RTL_DIR=..\..\..\rtl
set TP_DIR=..\..\third-party

REM -------------------------------------------------
REM Parameters (override before invoking this script)
REM -------------------------------------------------
if not defined DATA_WIDTH set DATA_WIDTH=8
if not defined SIMPLE set SIMPLE=0
if not defined ASYNC set ASYNC=0
if not defined BURST_SIZE set BURST_SIZE=4
if not defined ADDR_WIDTH set ADDR_WIDTH=4

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
vlog %INCLUDE_FLAGS% -sv ..\queue_push_coupler_tb.sv

IF ERRORLEVEL 1 (
    echo Compilation failed.
    cd ..
    exit /b 1
)

REM -------------------------------------------------
REM Run simulation (command line mode)
REM -------------------------------------------------
vsim -voptargs=+acc -c queue_push_coupler_tb -do "run -all; quit -f" ^
    -g/queue_push_coupler_tb/DATA_WIDTH=%DATA_WIDTH% ^
    -g/queue_push_coupler_tb/SIMPLE=%SIMPLE% ^
    -g/queue_push_coupler_tb/ASYNC=%ASYNC% ^
    -g/queue_push_coupler_tb/BURST_SIZE=%BURST_SIZE% ^
    -g/queue_push_coupler_tb/ADDR_WIDTH=%ADDR_WIDTH%
cd ..
