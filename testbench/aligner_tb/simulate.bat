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
if not defined DATA_WIDTH set DATA_WIDTH=8
if not defined SIZE set SIZE=4
if not defined REGISTERED_IN set REGISTERED_IN=1
if not defined START_SYMBOL_FANOUT_FACTOR set START_SYMBOL_FANOUT_FACTOR=4
if not defined REGISTERED_IN_START_SYMBOL set REGISTERED_IN_START_SYMBOL=1
if not defined REGISTERED_IN_EQUAL set REGISTERED_IN_EQUAL=1
if not defined REGISTERED_IN_PRIORITY_ENCODER set REGISTERED_IN_PRIORITY_ENCODER=1
if not defined REGISTERED_IN_REDUCTION_TREE set REGISTERED_IN_REDUCTION_TREE=1
if not defined REGISTERED_IN_MULTISTAGE_MUX set REGISTERED_IN_MULTISTAGE_MUX=1
if not defined LUTX_EQUAL set LUTX_EQUAL=4
if not defined LUTX_PRIORITY_ENCODER set LUTX_PRIORITY_ENCODER=4
if not defined LUTX_REDUCTION_TREE set LUTX_REDUCTION_TREE=4
if not defined LUTX_MULTISTAGE_MUX set LUTX_MULTISTAGE_MUX=4
if not defined GRADE_EQUAL set GRADE_EQUAL=1
if not defined GRADE_PRIORITY_ENCODER set GRADE_PRIORITY_ENCODER=1
if not defined GRADE_REDUCTION_TREE set GRADE_REDUCTION_TREE=1
if not defined GRADE_MULTISTAGE_MUX set GRADE_MULTISTAGE_MUX=1

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
vlog %INCLUDE_FLAGS% -sv ..\aligner_tb.sv

IF ERRORLEVEL 1 (
    echo Compilation failed.
    cd ..
    exit /b 1
)

REM -------------------------------------------------
REM Run simulation (command line mode)
REM -------------------------------------------------
vsim -voptargs=+acc -c ^
    -g/aligner_tb/DATA_WIDTH=%DATA_WIDTH% ^
    -g/aligner_tb/SIZE=%SIZE% ^
    -g/aligner_tb/REGISTERED_IN=%REGISTERED_IN% ^
    -g/aligner_tb/START_SYMBOL_FANOUT_FACTOR=%START_SYMBOL_FANOUT_FACTOR% ^
    -g/aligner_tb/REGISTERED_IN_START_SYMBOL=%REGISTERED_IN_START_SYMBOL% ^
    -g/aligner_tb/REGISTERED_IN_EQUAL=%REGISTERED_IN_EQUAL% ^
    -g/aligner_tb/REGISTERED_IN_PRIORITY_ENCODER=%REGISTERED_IN_PRIORITY_ENCODER% ^
    -g/aligner_tb/REGISTERED_IN_REDUCTION_TREE=%REGISTERED_IN_REDUCTION_TREE% ^
    -g/aligner_tb/REGISTERED_IN_MULTISTAGE_MUX=%REGISTERED_IN_MULTISTAGE_MUX% ^
    -g/aligner_tb/LUTX_EQUAL=%LUTX_EQUAL% ^
    -g/aligner_tb/LUTX_PRIORITY_ENCODER=%LUTX_PRIORITY_ENCODER% ^
    -g/aligner_tb/LUTX_REDUCTION_TREE=%LUTX_REDUCTION_TREE% ^
    -g/aligner_tb/LUTX_MULTISTAGE_MUX=%LUTX_MULTISTAGE_MUX% ^
    -g/aligner_tb/GRADE_EQUAL=%GRADE_EQUAL% ^
    -g/aligner_tb/GRADE_PRIORITY_ENCODER=%GRADE_PRIORITY_ENCODER% ^
    -g/aligner_tb/GRADE_REDUCTION_TREE=%GRADE_REDUCTION_TREE% ^
    -g/aligner_tb/GRADE_MULTISTAGE_MUX=%GRADE_MULTISTAGE_MUX% ^
    aligner_tb ^
    -do "vcd file waves.vcd; vcd add -r /*; run -all; vcd flush; quit -f" ^
    %*
cd ..
