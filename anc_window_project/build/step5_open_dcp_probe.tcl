if {$argc != 1} {
    puts stderr "USAGE: vivado -mode batch -source step5_open_dcp_probe.tcl -tclargs <post_synth.dcp>"
    exit 2
}
set dcp_path [file normalize [lindex $argv 0]]
if {![file exists $dcp_path]} {
    error "DCP not found: $dcp_path"
}
open_checkpoint $dcp_path
set cell_count [llength [get_cells -hierarchical]]
set port_count [llength [get_ports]]
puts "DCP_OPEN_OK cells=$cell_count ports=$port_count"
close_design
