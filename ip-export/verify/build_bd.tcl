# build_bd.tcl
# Self-contained Block Design build for the standalone axi_regs256 IP.
# Packages axi_regs256.sv, wires it to the Zynq UltraScale+ PS via
# M_AXI_HPM0_LPD through SmartConnect, synthesizes, implements, and writes
# a bitstream + XSA. No dependency on the parent zynq-axi-lite build scripts.
#
# Usage:
#   vivado -mode batch -source build_bd.tcl \
#       -tclargs <out_dir> <fpga_part> <board_part>
#
# Outputs: <out_dir>/axi_test.bit, <out_dir>/axi_test.xsa

# axi_regs256.sv lives one directory up (in ip-export/), this script is in ip-export/verify/
set script_dir [file dirname [file dirname [file normalize [info script]]]]

set OutDir    [string map {\\ /} [lindex $argv 0]]
set FpgaPart  [lindex $argv 1]
set BoardPart [lindex $argv 2]

if {$OutDir eq "" || $FpgaPart eq "" || $BoardPart eq ""} {
    puts "ERROR: Usage: vivado -mode batch -source build_bd.tcl -tclargs <out_dir> <fpga_part> <board_part>"
    exit 1
}

set ProjDir "$OutDir/vivado_proj"
set IpRepo  "$OutDir/ip_repo"
set BdName  "axi_test_bd"

file mkdir $OutDir

# ── Step 1: package axi_regs256.sv as a catalog IP ───────────────────────────
puts "INFO: Packaging axi_regs256.sv as IP..."
file delete -force $IpRepo
file mkdir $IpRepo

set pkg_proj_dir "$OutDir/_pkg_proj"
file delete -force $pkg_proj_dir
create_project -force pkg_proj $pkg_proj_dir -part $FpgaPart

add_files -norecurse [file join $script_dir axi_regs256.sv]
update_compile_order -fileset sources_1
set_property top axi_regs256_v1_0_S00_AXI [current_fileset]

ipx::package_project -root_dir $IpRepo -vendor user.org -library user -taxonomy /UserIP \
    -import_files -force
set_property name axi_regs256_v1_0 [ipx::current_core]
set_property display_name "AXI Regs256" [ipx::current_core]
set_property description \
    "Hardware-verified AXI4-Lite loopback register file (256 x 32-bit). reg\[0\] = 0xA0100001 ping constant (read-only), reg\[1..255\] = read/write loopback." \
    [ipx::current_core]
ipx::create_xgui_files [ipx::current_core]
ipx::update_checksums [ipx::current_core]
ipx::save_core [ipx::current_core]
close_project
puts "INFO: IP packaged to $IpRepo"

# ── Step 2: build the test project + block design ───────────────────────────
create_project axi_test $ProjDir -part $FpgaPart -force
set_property board_part $BoardPart [current_project]

set_property ip_repo_paths $IpRepo [current_project]
update_ip_catalog -rebuild

create_bd_design $BdName

# -- Zynq PS --
create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e:3.5 zynq_ultra_ps_e_0
apply_bd_automation -rule xilinx.com:bd_rule:zynq_ultra_ps_e \
    -config {apply_board_preset "1"} [get_bd_cells zynq_ultra_ps_e_0]
set_property -dict [list \
    CONFIG.PSU__USE__M_AXI_GP0                  {0}   \
    CONFIG.PSU__USE__M_AXI_GP1                  {0}   \
    CONFIG.PSU__USE__M_AXI_GP2                  {1}   \
    CONFIG.PSU__MAXIGP2__DATA_WIDTH             {32}  \
    CONFIG.PSU__CRL_APB__PL0_REF_CTRL__FREQMHZ  {100} \
    CONFIG.PSU__FPGA_PL0_ENABLE                 {1}   \
] [get_bd_cells zynq_ultra_ps_e_0]

# -- Proc System Reset --
create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_0

# -- SmartConnect: converts AXI4 -> AXI4-Lite internally --
create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 axi_smc
set_property -dict [list CONFIG.NUM_SI {1} CONFIG.NUM_MI {1}] [get_bd_cells axi_smc]

# -- axi_regs256 packaged IP --
create_bd_cell -type ip -vlnv user.org:user:axi_regs256_v1_0:1.0 u_regs

# ── Clocks ────────────────────────────────────────────────────────────────────
connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] \
               [get_bd_pins zynq_ultra_ps_e_0/maxihpm0_lpd_aclk]
connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] \
               [get_bd_pins proc_sys_reset_0/slowest_sync_clk]
connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_resetn0] \
               [get_bd_pins proc_sys_reset_0/ext_reset_in]
connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] [get_bd_pins axi_smc/aclk]
connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] [get_bd_pins u_regs/S_AXI_ACLK]

# ── Resets ────────────────────────────────────────────────────────────────────
connect_bd_net [get_bd_pins proc_sys_reset_0/peripheral_aresetn] \
               [get_bd_pins axi_smc/aresetn]
connect_bd_net [get_bd_pins proc_sys_reset_0/peripheral_aresetn] \
               [get_bd_pins u_regs/S_AXI_ARESETN]

# ── AXI connections -- M_AXI_HPM0_LPD, NOT FPD (see ip-export/README.md) ─────
connect_bd_intf_net [get_bd_intf_pins zynq_ultra_ps_e_0/M_AXI_HPM0_LPD] \
                    [get_bd_intf_pins axi_smc/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_smc/M00_AXI] \
                    [get_bd_intf_pins u_regs/S_AXI]

# ── Address assignment ────────────────────────────────────────────────────────
assign_bd_address
foreach seg [get_bd_addr_segs -of_objects [get_bd_addr_spaces zynq_ultra_ps_e_0/Data]] {
    if {[string match "*u_regs*" $seg]} {
        set_property offset 0x80000000 $seg
        set_property range  0x00000400 $seg
        puts "INFO: Mapped $seg -> 0x80000000 (1KB, full 256-register axi_regs256 IP)"
    }
}

validate_bd_design
save_bd_design

set WrapperFile [make_wrapper -files [get_files ${BdName}.bd] -top -force]
add_files -norecurse $WrapperFile
set_property top ${BdName}_wrapper [current_fileset]
update_compile_order -fileset sources_1

generate_target all [get_files ${BdName}.bd]

# ── Synthesis ─────────────────────────────────────────────────────────────────
puts "INFO: Launching synthesis..."
set_property STEPS.SYNTH_DESIGN.ARGS.FLATTEN_HIERARCHY none [get_runs synth_1]
launch_runs synth_1 -jobs 4
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
    error "Synthesis failed: [get_property STATUS [get_runs synth_1]]"
}
puts "INFO: Synthesis complete."
open_run synth_1 -name synth_1

# ── Implementation ────────────────────────────────────────────────────────────
puts "INFO: Launching implementation..."
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    error "Implementation failed: [get_property STATUS [get_runs impl_1]]"
}
puts "INFO: Implementation complete."
open_run impl_1

# ── Outputs ───────────────────────────────────────────────────────────────────
write_bitstream -force "$OutDir/axi_test.bit"
write_hw_platform -fixed -force -file "$OutDir/axi_test.xsa"

puts "INFO: Done."
puts "INFO: Bitstream : $OutDir/axi_test.bit"
puts "INFO: XSA       : $OutDir/axi_test.xsa"
