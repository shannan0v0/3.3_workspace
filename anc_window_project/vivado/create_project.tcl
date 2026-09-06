# Simulation-first Vivado project handoff. No board part or pins are embedded.
if {$argc < 1} {
    puts stderr "USAGE: vivado -mode batch -source create_project.tcl -tclargs <exact_part> [project_dir]"
    exit 2
}
set script_dir [file dirname [file normalize [info script]]]
set root_dir [file normalize [file join $script_dir ..]]
set part_name [lindex $argv 0]
if {$argc >= 2} {
    set project_dir [file normalize [lindex $argv 1]]
} else {
    set project_dir [file normalize [file join $script_dir work]]
}
set xpr_path [file join $project_dir anc_window.xpr]
if {[file exists $xpr_path]} {
    error "Refusing to overwrite existing project: $xpr_path"
}
set rtl_dir [file join $root_dir rtl]
set rtl_files [lsort [glob -nocomplain -directory $rtl_dir *.sv]]
if {[llength $rtl_files] == 0} {
    error "No SystemVerilog sources found under $rtl_dir"
}
create_project anc_window $project_dir -part $part_name
foreach source_file $rtl_files {
    add_files -fileset sources_1 $source_file
}
set_property top anc_top [get_filesets sources_1]
set xdc_path [file join $script_dir constraints AX7020_template.xdc]
if {[file exists $xdc_path]} {
    add_files -fileset constrs_1 $xdc_path
} else {
    puts "INFO: no XDC template found; continue without constraints"
}
update_compile_order -fileset sources_1
# create_project persists the XPR; Vivado 2025.2.1 has no bare save_project command.
puts "HANDOFF_PROJECT_CREATED part=$part_name sources=[llength $rtl_files] path=$xpr_path"
