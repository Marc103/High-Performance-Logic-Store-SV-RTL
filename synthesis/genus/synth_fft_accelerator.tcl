# Run from any directory in a fresh Genus Stylus/Common UI process:
#   genus -no_gui -batch -files /path/to/synthesis/genus/synth_fft_accelerator.tcl
# Synthesis only: wire-load interconnect, no placement/CTS/routing or DFT.
# Set FFT_GENUS_NETLIST to a prior mapped .v to regenerate reports/exports
# without running syn_generic/syn_map/syn_opt again.
source [file join [file dirname [file normalize [info script]]] config.tcl]

namespace eval ::fft_syn {
    proc require_file {path} {
        if {![file isfile $path] || ![file readable $path] || [file size $path] == 0} {
            error "Missing/unreadable file: $path"
        }
    }

    proc write_text {path text} {
        set stream [open $path w]
        puts $stream $text
        close $stream
    }

    proc check_structure {path} {
        check_design -unresolved > $path
        set stream [open $path r]
        set report [read $stream]
        close $stream
        # Genus 18 can report "No unresolved references" while also listing
        # empty HDL modules. For this accelerator, review those before mapping:
        # an empty reset pipe leaves its output undriven in the exported netlist.
        if {[regexp -nocase {Total number of empty modules[^\n]*:\s*([0-9]+)} $report match count] && $count > 0} {
            error "Design contains $count empty modules; inspect $path before synthesis/export."
        }
    }

    proc main {} {
        variable cfg
        variable parameters
        variable corners
        variable script_dir
        variable repo_root
        variable relative_sources

        # Check inputs before reading any libraries or starting synthesis.
        foreach key [array names cfg *_ns] {
            if {![string is double -strict $cfg($key)]} {
                error "$key must be a number in ns"
            }
            if {$cfg($key) < 0 && $key ni {input_delay_min_ns output_delay_min_ns}} {
                error "$key must be nonnegative (only minimum I/O delays may be negative)"
            }
        }
        if {$cfg(clock_period_ns) <= 0} {error "clock_period_ns must be positive"}
        if {$cfg(input_delay_min_ns) > $cfg(input_delay_max_ns) ||
            $cfg(output_delay_min_ns) > $cfg(output_delay_max_ns)} {
            error "Minimum I/O delay must not exceed maximum I/O delay"
        }
        if {![string is double -strict $cfg(output_load_ff)] || $cfg(output_load_ff) < 0} {
            error "output_load_ff must be nonnegative, in fF"
        }
        if {$cfg(effort) ni {low medium high}} {error "effort must be low, medium or high"}
        set parameter_pairs {}
        foreach name [lsort [array names parameters]] {
            if {![string is integer -strict $parameters($name)]} {
                error "RTL parameter $name must be an integer"
            }
            lappend parameter_pairs [list $name $parameters($name)]
        }
        if {$parameters(II_CYCLES) < 4 || $parameters(READ_LATENCY) < 1 ||
            $parameters(WRITE_LATENCY) < 1 || $parameters(RESET_PIPELINE_DEPTH) < 0} {
            error "Invalid launch interval, memory latency or reset depth"
        }

        set sources {}
        set export_only [expr {$cfg(mapped_netlist) ne ""}]
        if {$export_only} {
            set sources [list [file normalize $cfg(mapped_netlist)]]
            require_file [lindex $sources 0]
        } else {
            foreach relative $relative_sources {
                set absolute [file normalize [file join $repo_root $relative]]
                require_file $absolute
                lappend sources $absolute
            }
        }
        set libdir [file normalize [file join $cfg(library_root) Front_End Liberty NLDM]]
        set libraries {}
        dict for {corner pvt} $corners {
            set path [file join $libdir NangateOpenCellLibrary_${corner}.lib]
            require_file $path
            dict set libraries $corner $path
        }
        set template_path [file join $script_dir constraints.sdc]
        require_file $template_path

        set out [file normalize $cfg(output_dir)]
        # Each run gets its own directory; never silently overwrite an old netlist.
        if {[file exists $out]} {
            error "Output directory already exists: $out. Select a new FFT_GENUS_OUT."
        }
        file mkdir [file join $out outputs] [file join $out reports]

        set sdc_text "# Resolved synthesis constraints; ns and fF.\n"
        foreach key [lsort [array names cfg]] {
            if {[string match *_ns $key] || $key eq "output_load_ff"} {
                append sdc_text [list set FFT_[string toupper $key] $cfg($key)] "\n"
            }
        }
        set stream [open $template_path r]
        append sdc_text [read $stream]
        close $stream
        set sdc_path [file join $out outputs fft_accelerator.constraints.sdc]
        write_text $sdc_path $sdc_text

        # Keep homonymous Liberty libraries in distinct MMMC library sets.
        # Loading the five files as one flat 'library' list would mix PVT data.
        set mmmc "# Resolved Genus MMMC setup: logical wire-load synthesis.\n"
        append mmmc [list create_constraint_mode -name functional -sdc_files [list $sdc_path]] "\n"
        set views {}
        dict for {corner pvt} $corners {
            lassign $pvt voltage temperature
            lappend views view_$corner
            append mmmc [list create_library_set -name lib_$corner \
                -timing [list [dict get $libraries $corner]]] "\n"
            append mmmc [list create_opcond -name op_$corner \
                -process 1.0 -voltage $voltage -temperature $temperature] "\n"
            append mmmc [list create_timing_condition -name tc_$corner \
                -library_sets [list lib_$corner] -opcond op_$corner] "\n"
            # No extracted RC technology is claimed. Wire parasitics are
            # estimated from Liberty wire-load tables, selected by Genus.
            append mmmc [list create_rc_corner -name rc_$corner -temperature $temperature] "\n"
            append mmmc [list create_delay_corner -name dc_$corner \
                -early_timing_condition tc_$corner -late_timing_condition tc_$corner \
                -early_rc_corner rc_$corner -late_rc_corner rc_$corner] "\n"
            append mmmc [list create_analysis_view -name view_$corner \
                -constraint_mode functional -delay_corner dc_$corner] "\n"
        }
        # Optimize one common implementation against all five setup views;
        # retain all five hold views too. Do not assume which cold/hot corner
        # is globally fastest or slowest for every cell/path.
        append mmmc [list set_analysis_view -setup $views -hold $views] "\n"
        set mmmc_path [file join $out outputs fft_accelerator.mmmc.tcl]
        write_text $mmmc_path $mmmc

        write_text [file join $out run_config.tcl] \
            "# Resolved settings; parameters apply only when synthesizing RTL.\n[list set configuration [array get cfg]]\n[list set export_only $export_only]\n[list set rtl_parameters $parameter_pairs]\n[list set design_sources $sources]\n[list set nldm_libraries $libraries]"
        puts [format "FFT synthesis: requested period = %.6f ns (%.3f MHz)" \
            $cfg(clock_period_ns) [expr {1000.0 / $cfg(clock_period_ns)}]]
        puts "RTL parameters: $parameter_pairs"
        puts "Active setup/hold views: $views"
        puts "Output directory: $out"
        if {$export_only} {
            puts "Export-only: reading mapped netlist [lindex $sources 0]; synthesis is skipped."
        }

        set_db init_hdl_search_path [list [file join $repo_root rtl]]
        set_db init_lib_search_path [list $libdir]
        set_db interconnect_mode wireload
        # Preserve the public top name even though elaborate overrides its
        # parameters. Genus uniquifies different child specializations itself.
        set_db hdl_parameter_naming_style ""
        set_db hdl_error_on_blackbox true
        set_db hdl_error_on_latch true
        set_db syn_generic_effort $cfg(effort)
        set_db syn_map_effort $cfg(effort)
        set_db syn_opt_effort $cfg(effort)

        read_mmmc $mmmc_path
        read_hdl -sv $sources
        if {$export_only} {
            # The cell netlist has fixed widths/parameters. Library references
            # are linked during elaboration; no RTL parameter overrides apply.
            elaborate fft_accelerator
        } else {
            elaborate fft_accelerator -parameters $parameter_pairs
        }
        init_design
        check_structure [file join $out reports elaboration.rpt]
        check_timing_intent > [file join $out reports timing_intent_pre.rpt]

        if {!$export_only} {
            syn_generic
            syn_map
            syn_opt
        }

        check_structure [file join $out reports mapped_design.rpt]
        check_timing_intent > [file join $out reports timing_intent_post.rpt]
        report_area > [file join $out reports area.rpt]
        report_gates > [file join $out reports gates.rpt]
        report_design_rules > [file join $out reports design_rules.rpt]
        report_qor > [file join $out reports qor.rpt]

        # The SAME final mapped netlist is used with each corner SDF.
        write_hdl > [file join $out outputs fft_accelerator.mapped.v]
        # Genus requires an explicit view for MMMC SDC export. Every view
        # references the same functional mode, so one representative suffices.
        write_sdc -view view_typical > [file join $out outputs fft_accelerator.mapped.sdc]
        # The user's Genus 2018 report_timing rejects -early. Do not replace it
        # with another unverified option or label a setup report as hold timing.
        write_text [file join $out reports hold_analysis.txt] \
            "NOT PERFORMED: this flow does not run hold STA in Genus 2018.\nThe report_timing -early option is unsupported by that command.\nHold constraints and MMMC hold views are retained. Perform hold STA in a compatible timing tool (for example, Tempus/Innovus)."
        dict for {corner pvt} $corners {
            report_timing -views view_$corner -max_paths 20 \
                > [file join $out reports ${corner}.setup.rpt]
            # Keep timing checks and their signs for timing GLS. No
            # -nonegchecks option, and no output renaming after SDF export.
            write_sdf -view view_$corner -timescale ns \
                > [file join $out outputs fft_accelerator.${corner}.sdf]
        }
        puts "Mapped netlist and five corner SDFs written to [file join $out outputs]"
        puts "Inspect timing intent, mapped-design and all corner setup reports."
        puts "Hold STA was not performed; see reports/hold_analysis.txt."
        puts "Completion means files were generated; it does not certify timing closure."
    }
}

if {[catch {::fft_syn::main} message options]} {
    puts stderr "FFT SYNTHESIS FAILED: $message"
    puts stderr [dict get $options -errorinfo]
    exit 1
}
exit 0
