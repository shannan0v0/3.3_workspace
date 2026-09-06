# Synthesis-only report handoff. Requires an exact-part project created first.
if {$argc < 1} {
    puts stderr "USAGE: vivado -mode batch -source run_synth_reports.tcl -tclargs <project.xpr> [report_dir]"
    exit 2
}
set project_xpr [file normalize [lindex $argv 0]]
if {![file exists $project_xpr]} {
    error "Project not found: $project_xpr"
}
if {$argc >= 2} {
    set report_dir [file normalize [lindex $argv 1]]
} else {
    set report_dir [file join [file dirname $project_xpr] reports]
}
file mkdir $report_dir
open_project $project_xpr
set part_name [get_property PART [current_project]]
puts "SYNTH_START part=$part_name top=[get_property top [get_filesets sources_1]]"
synth_design -top anc_top -part $part_name
report_utilization -file [file join $report_dir synth_utilization.rpt]
report_timing_summary -file [file join $report_dir synth_timing_summary.rpt]
write_checkpoint -force [file join $report_dir post_synth.dcp]
puts "SYNTH_REPORTS_WRITTEN dir=$report_dir"
close_project
