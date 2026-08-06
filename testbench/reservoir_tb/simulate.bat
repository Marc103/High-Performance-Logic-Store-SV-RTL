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
REM   set DATA_WIDTH=16
REM   set WATERMARK_ENTRIES=5
REM   set BACKPRESSURE_ENTRIES=3
REM   set BURSTMARK=4
REM   simulate.bat
REM -------------------------------------------------
if not defined DATA_WIDTH set DATA_WIDTH=8
if not defined WATERMARK_ENTRIES set WATERMARK_ENTRIES=4
if not defined BACKPRESSURE_ENTRIES set BACKPRESSURE_ENTRIES=2
if not defined BURSTMARK set BURSTMARK=2

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
vlog %INCLUDE_FLAGS% -sv ..\reservoir_tb.sv

IF ERRORLEVEL 1 (
    echo Compilation failed.
    cd ..
    exit /b 1
)

REM -------------------------------------------------
REM Run simulation (command line mode)
REM -------------------------------------------------
vsim -voptargs=+acc -c ^
    -g/reservoir_tb/DATA_WIDTH=%DATA_WIDTH% ^
    -g/reservoir_tb/WATERMARK_ENTRIES=%WATERMARK_ENTRIES% ^
    -g/reservoir_tb/BACKPRESSURE_ENTRIES=%BACKPRESSURE_ENTRIES% ^
    -g/reservoir_tb/BURSTMARK=%BURSTMARK% ^
    reservoir_tb ^
    -do "run -all; quit -f" ^
    %*
cd ..
