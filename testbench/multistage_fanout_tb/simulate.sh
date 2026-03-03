export bindir="/usr/local/diamond/3.13/bin/lin64"
source /usr/local/diamond/3.13/bin/lin64/diamond_env

rm -rf simulate
mkdir simulate
cd simulate
vlib work

# Directories
TB_DIR="../../testbench"
CT_DIR="../../components"
RTL_DIR="../../../rtl"
TP_DIR="../../../rtl/third_party"
PJ_DIR="../../../projects"

# Include directory flags
INCLUDE_FLAGS="-incdir "$RTL_DIR" 
               -incdir "$TB_DIR" 
               -incdir "$TP_DIR" 
               -incdir "$CT_DIR"/drivers
               -incdir "$CT_DIR"/generators
               -incdir "$CT_DIR"/golden_models
               -incdir "$CT_DIR"/interfaces
               -incdir "$CT_DIR"/monitors
               -incdir "$CT_DIR"/package_manager
               -incdir "$CT_DIR"/scoreboards
               -incdir "$CT_DIR"/utilities
               -incdir "$PJ_DIR"/dfdd
               "

# Run vlog on all source files.
error_highlighter() {
    grep --color -e ".*Errors: [1-9].*" -e "^"
}


vlog $INCLUDE_FLAGS -sv ../example_tb.sv | error_highlighter

export bindir=""

# -c argument gets name of testbench module.
vsim -c example_tb -do "run -all; quit" | error_highlighter

# Using the Modelsim OEM bundled with Diamond on Ubuntu 24.04
# setting up requires first grabbing a free floating license then debugging missing 
# packages that needs to be installed.
# Make sure you have these lines in your bashrc:
# export PATH="/usr/local/diamond/3.13/bin/lin64:$PATH" 
# export PATH="/usr/local/diamond/3.13/modeltech/linuxloem:$PATH" 
# export PATH="/usr/local/diamond/3.13/bin/lin64/toolapps/:$PATH"
# At some point, once you think you've installed the packages, it will start to complain
# about licensing, but actually there are still missing packages to install first.
# To find out which ones are missing, run the vsim gui directly found at 
# 'usr/local/diamond/3.13/modeltech/bin', some error messages will pop up detailing
# which additional packages are missing.
