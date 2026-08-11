@echo off

rmdir /s /q simulate 2>nul
mkdir simulate
cd simulate

vlib work

set TB_DIR=..\..\testbench
set CT_DIR=..\..\components
set RTL_DIR=..\..\..\rtl
set TP_DIR=..\..\third-party

if not defined DATA_WIDTH set DATA_WIDTH=8
if not defined ADDR_WIDTH set ADDR_WIDTH=4
if not defined ASYNC set ASYNC=0
if not defined BURSTMARK set BURSTMARK=4
if not defined CONFLICT_PROOF set CONFLICT_PROOF=1
if not defined REGISTERED_IN set REGISTERED_IN=1
if not defined REGISTERED_IN_BRAM set REGISTERED_IN_BRAM=1
if not defined REGISTERED_OUT_BRAM set REGISTERED_OUT_BRAM=1

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

vlog %INCLUDE_FLAGS% -sv ..\queue_pop_coupler_tb.sv

IF ERRORLEVEL 1 (
    echo Compilation failed.
    cd ..
    exit /b 1
)

vsim -voptargs=+acc -c ^
    -g/queue_pop_coupler_tb/DATA_WIDTH=%DATA_WIDTH% ^
    -g/queue_pop_coupler_tb/ADDR_WIDTH=%ADDR_WIDTH% ^
    -g/queue_pop_coupler_tb/ASYNC=%ASYNC% ^
    -g/queue_pop_coupler_tb/BURSTMARK=%BURSTMARK% ^
    -g/queue_pop_coupler_tb/CONFLICT_PROOF=%CONFLICT_PROOF% ^
    -g/queue_pop_coupler_tb/REGISTERED_IN=%REGISTERED_IN% ^
    -g/queue_pop_coupler_tb/REGISTERED_IN_BRAM=%REGISTERED_IN_BRAM% ^
    -g/queue_pop_coupler_tb/REGISTERED_OUT_BRAM=%REGISTERED_OUT_BRAM% ^
    queue_pop_coupler_tb ^
    -do "vcd file waves.vcd; vcd add -r /*; run -all; vcd flush; quit -f"

cd ..
