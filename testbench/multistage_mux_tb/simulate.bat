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
REM   set DATA_WIDTH=8
REM   set SIZE=10
REM   set REGISTERED_IN=1
REM   set LUTX=6
REM   set GRADE=2
REM   simulate.bat
REM -------------------------------------------------
if not defined DATA_WIDTH set DATA_WIDTH=12
if not defined SIZE set SIZE=17
if not defined REGISTERED_IN set REGISTERED_IN=0
if not defined LUTX set LUTX=4
if not defined GRADE set GRADE=2

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
vlog %INCLUDE_FLAGS% -sv ..\multistage_mux_tb.sv

IF ERRORLEVEL 1 (
    echo Compilation failed.
    cd ..
    exit /b 1
)

REM -------------------------------------------------
REM Run simulation (command line mode)
REM -------------------------------------------------
vsim -voptargs=+acc -c ^
    -g/multistage_mux_tb/DATA_WIDTH=%DATA_WIDTH% ^
    -g/multistage_mux_tb/SIZE=%SIZE% ^
    -g/multistage_mux_tb/REGISTERED_IN=%REGISTERED_IN% ^
    -g/multistage_mux_tb/LUTX=%LUTX% ^
    -g/multistage_mux_tb/GRADE=%GRADE% ^
    multistage_mux_tb ^
    -do "vcd file waves.vcd; vcd add -r /*; run -all; vcd flush; quit -f" ^
    %*
cd ..
