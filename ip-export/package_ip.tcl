# package_ip.tcl
#
# Packages axi_regs256.sv (in this folder) as a reusable Vivado IP
# (axi_regs256_v1_0) that can be added to the IP catalog of ANY Vivado
# project and dropped into a Block Design.
#
# Usage (from a Vivado Tcl console, or `vivado -mode batch -source package_ip.tcl`):
#
#   set repo_dir   [pwd]                 ;# defaults to this script's folder
#   set out_dir    <path-to-project>/ip_repo
#
#   vivado -mode batch -source package_ip.tcl -tclargs <out_dir>
#
# After packaging, add <out_dir> as an IP repository in your target project:
#   Tools -> Settings -> IP -> Repository -> Add -> <out_dir>
# then refresh the catalog and instantiate "AXI Regs256 (0x0)" in your
# Block Design like any other IP.

set script_dir [file dirname [file normalize [info script]]]

# Output directory for the packaged IP (first script arg, default ./out_ip)
if { $argc >= 1 } {
    set out_dir [lindex $argv 0]
} else {
    set out_dir [file join $script_dir out_ip]
}

file mkdir $out_dir

# Scratch project used only to run the IP Packager
set proj_dir [file join $script_dir _pkg_proj]
file delete -force $proj_dir

create_project -force pkg_proj $proj_dir -part xczu9eg-ffvb1156-2-e

add_files -norecurse [file join $script_dir axi_regs256.sv]
update_compile_order -fileset sources_1

set_property top axi_regs256_v1_0_S00_AXI [current_fileset]

ipx::package_project -root_dir $out_dir -vendor user.org -library user -taxonomy /UserIP \
    -import_files -force

set_property name axi_regs256_v1_0 [ipx::current_core]
set_property display_name "AXI Regs256" [ipx::current_core]
set_property description \
    "Hardware-verified AXI4-Lite loopback register file (256 x 32-bit). reg[0] = 0xA0100001 ping constant (read-only), reg[1..255] = read/write loopback." \
    [ipx::current_core]

# Standard AXI4-Lite bus interface association (usually auto-detected from
# the X_INTERFACE_INFO attributes in the .sv, but set explicitly to be safe).
ipx::add_bus_interface S_AXI [ipx::current_core]

ipx::create_xgui_files [ipx::current_core]
ipx::update_checksums [ipx::current_core]
ipx::save_core [ipx::current_core]

close_project

puts "Packaged IP written to: $out_dir"
puts "Add this directory as an IP Repository in your target project, then"
puts "refresh the IP catalog and instantiate 'AXI Regs256' in your Block Design."
