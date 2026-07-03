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
REM Parameter defaults
REM Override from cmd before calling, for example:
REM   set ADDR_WIDTH=3
REM   set DATA_WIDTH=16
REM   set CONFLICT_PROOF=1
REM   set REGISTERED_IN=1
REM   set REGISTERED_IN_BRAM=1
REM   set REGISTERED_OUT_BRAM=1
REM   set NUMBER_OF_QUEUES=3
REM   simulate.bat
REM -------------------------------------------------
if not defined ADDR_WIDTH set ADDR_WIDTH=3
if not defined DATA_WIDTH set DATA_WIDTH=16
if not defined CONFLICT_PROOF set CONFLICT_PROOF=1
if not defined REGISTERED_IN set REGISTERED_IN=1
if not defined REGISTERED_IN_BRAM set REGISTERED_IN_BRAM=1
if not defined REGISTERED_OUT_BRAM set REGISTERED_OUT_BRAM=1
if not defined NUMBER_OF_QUEUES set NUMBER_OF_QUEUES=3

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
vlog %INCLUDE_FLAGS% -sv ..\queue_tb.sv

IF ERRORLEVEL 1 (
    echo Compilation failed.
    cd ..
    exit /b 1
)

REM -------------------------------------------------
REM Run simulation (command line mode)
REM -------------------------------------------------
vsim -voptargs=+acc -c ^
    -g/queue_tb/ADDR_WIDTH=%ADDR_WIDTH% ^
    -g/queue_tb/DATA_WIDTH=%DATA_WIDTH% ^
    -g/queue_tb/CONFLICT_PROOF=%CONFLICT_PROOF% ^
    -g/queue_tb/REGISTERED_IN=%REGISTERED_IN% ^
    -g/queue_tb/REGISTERED_IN_BRAM=%REGISTERED_IN_BRAM% ^
    -g/queue_tb/REGISTERED_OUT_BRAM=%REGISTERED_OUT_BRAM% ^
    -g/queue_tb/NUMBER_OF_QUEUES=%NUMBER_OF_QUEUES% ^
    queue_tb ^
    -do "vcd file waves.vcd; vcd add -r /*; run -all; vcd flush; quit -f" ^
    %*
cd ..
