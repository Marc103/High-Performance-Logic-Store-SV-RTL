@echo off
setlocal
set "SCRIPT_DIR=%~dp0"
for %%I in ("%SCRIPT_DIR%..\..") do set "REPO_ROOT=%%~fI"
set "RTL_DIR=%REPO_ROOT%\rtl"
set "CT_DIR=%REPO_ROOT%\testbench\components"
REM Parameter overrides are forwarded to vsim, e.g. simulate.bat -gBASE=4 -gMANTISSA_WIDTH=6
pushd "%SCRIPT_DIR%"
if not exist simulate mkdir simulate
pushd simulate
if not exist work vlib work
if errorlevel 1 goto failed
vlog -sv +incdir+"%RTL_DIR%" +incdir+"%REPO_ROOT%\testbench" ^
 +incdir+"%CT_DIR%\drivers" +incdir+"%CT_DIR%\generators" ^
 +incdir+"%CT_DIR%\golden_models" +incdir+"%CT_DIR%\interfaces" ^
 +incdir+"%CT_DIR%\monitors" +incdir+"%CT_DIR%\package_manager" ^
 +incdir+"%CT_DIR%\scoreboards" +incdir+"%CT_DIR%\io" ^
 +incdir+"%CT_DIR%\utilities" "%SCRIPT_DIR%fft_multiplier_core_tb.sv"
if errorlevel 1 goto failed
if exist transcript del /q transcript
vsim -c -voptargs=+acc -onfinish stop fft_multiplier_core_tb %* -do "run -all; vcd flush; quit -code 0 -f"
if errorlevel 1 goto failed
findstr /C:"Scoreboard completed:" transcript >nul
if errorlevel 1 goto failed
popd
popd
exit /b 0
:failed
popd
popd
exit /b 1
