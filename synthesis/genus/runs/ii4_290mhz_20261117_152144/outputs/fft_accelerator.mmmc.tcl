# Resolved Genus MMMC setup: logical wire-load synthesis.
create_constraint_mode -name functional -sdc_files /home/guy3027/High-Performance-Logic-Store-SV-RTL/synthesis/genus/runs/ii4_290mhz_20261117_152144/outputs/fft_accelerator.constraints.sdc
create_library_set -name lib_slow -timing /home/guy3027/High-Performance-Logic-Store-SV-RTL/synthesis/genus/libraries/NangateOpenCellLibrary/Front_End/Liberty/NLDM/NangateOpenCellLibrary_slow.lib
create_opcond -name op_slow -process 1.0 -voltage 0.95 -temperature 125.0
create_timing_condition -name tc_slow -library_sets lib_slow -opcond op_slow
create_rc_corner -name rc_slow -temperature 125.0
create_delay_corner -name dc_slow -early_timing_condition tc_slow -late_timing_condition tc_slow -early_rc_corner rc_slow -late_rc_corner rc_slow
create_analysis_view -name view_slow -constraint_mode functional -delay_corner dc_slow
create_library_set -name lib_worst_low -timing /home/guy3027/High-Performance-Logic-Store-SV-RTL/synthesis/genus/libraries/NangateOpenCellLibrary/Front_End/Liberty/NLDM/NangateOpenCellLibrary_worst_low.lib
create_opcond -name op_worst_low -process 1.0 -voltage 0.95 -temperature -40.0
create_timing_condition -name tc_worst_low -library_sets lib_worst_low -opcond op_worst_low
create_rc_corner -name rc_worst_low -temperature -40.0
create_delay_corner -name dc_worst_low -early_timing_condition tc_worst_low -late_timing_condition tc_worst_low -early_rc_corner rc_worst_low -late_rc_corner rc_worst_low
create_analysis_view -name view_worst_low -constraint_mode functional -delay_corner dc_worst_low
create_library_set -name lib_typical -timing /home/guy3027/High-Performance-Logic-Store-SV-RTL/synthesis/genus/libraries/NangateOpenCellLibrary/Front_End/Liberty/NLDM/NangateOpenCellLibrary_typical.lib
create_opcond -name op_typical -process 1.0 -voltage 1.10 -temperature 25.0
create_timing_condition -name tc_typical -library_sets lib_typical -opcond op_typical
create_rc_corner -name rc_typical -temperature 25.0
create_delay_corner -name dc_typical -early_timing_condition tc_typical -late_timing_condition tc_typical -early_rc_corner rc_typical -late_rc_corner rc_typical
create_analysis_view -name view_typical -constraint_mode functional -delay_corner dc_typical
create_library_set -name lib_fast -timing /home/guy3027/High-Performance-Logic-Store-SV-RTL/synthesis/genus/libraries/NangateOpenCellLibrary/Front_End/Liberty/NLDM/NangateOpenCellLibrary_fast.lib
create_opcond -name op_fast -process 1.0 -voltage 1.25 -temperature 0.0
create_timing_condition -name tc_fast -library_sets lib_fast -opcond op_fast
create_rc_corner -name rc_fast -temperature 0.0
create_delay_corner -name dc_fast -early_timing_condition tc_fast -late_timing_condition tc_fast -early_rc_corner rc_fast -late_rc_corner rc_fast
create_analysis_view -name view_fast -constraint_mode functional -delay_corner dc_fast
create_library_set -name lib_low_temp -timing /home/guy3027/High-Performance-Logic-Store-SV-RTL/synthesis/genus/libraries/NangateOpenCellLibrary/Front_End/Liberty/NLDM/NangateOpenCellLibrary_low_temp.lib
create_opcond -name op_low_temp -process 1.0 -voltage 1.25 -temperature -40.0
create_timing_condition -name tc_low_temp -library_sets lib_low_temp -opcond op_low_temp
create_rc_corner -name rc_low_temp -temperature -40.0
create_delay_corner -name dc_low_temp -early_timing_condition tc_low_temp -late_timing_condition tc_low_temp -early_rc_corner rc_low_temp -late_rc_corner rc_low_temp
create_analysis_view -name view_low_temp -constraint_mode functional -delay_corner dc_low_temp
set_analysis_view -setup {view_slow view_worst_low view_typical view_fast view_low_temp} -hold {view_slow view_worst_low view_typical view_fast view_low_temp}

