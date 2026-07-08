# build_axi_test.tcl
# AXI4-Lite loopback test for ZCU102: 256 x 32-bit register file with a
# hardwired PING_CONST at reg0, accessed from Linux userspace via
# M_AXI_HPM0_LPD (see research-history.md for why LPD instead of FPD).
#
# Architecture:
#   PS M_AXI_HPM0_LPD (ARM @ 0x80000000)
#       -> SmartConnect (handles AXI4->AXI4-Lite conversion internally)
#       -> axi_regs256 (packaged IP, 256 x 32-bit loopback registers)
#
# Usage (from repo root):
#   vivado -mode batch -source scripts/build_axi_test.tcl \
#       -tclargs <out_dir> <ip_repo> <fpga_part> <board_part>
#
# Outputs: <out_dir>/axi_test.bit, <out_dir>/axi_test.xsa

# ── Args from 2.BuildBitstream.ps1 via -tclargs ─────────────────────────────
set OutDir   [string map {\\ /} [lindex $argv 0]]
set IpRepo   [string map {\\ /} [lindex $argv 1]]
set FpgaPart [lindex $argv 2]
set BoardPart [lindex $argv 3]

if {$OutDir eq "" || $FpgaPart eq "" || $BoardPart eq ""} {
    puts "ERROR: Usage: vivado -mode batch -source build_axi_test.tcl -tclargs <out_dir> <ip_repo> <fpga_part> <board_part>"
    exit 1
}

set ProjDir "$OutDir/vivado_proj"
set BdName  "axi_test_bd"

file mkdir $OutDir

# ── Create project ────────────────────────────────────────────────────────────
create_project axi_test $ProjDir -part $FpgaPart -force
set_property board_part $BoardPart [current_project]

# ── Add packaged IP repo ──────────────────────────────────────────────────────
set_property ip_repo_paths $IpRepo [current_project]
update_ip_catalog -rebuild

# ── Block Design ─────────────────────────────────────────────────────────────
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

# -- SmartConnect: 1 master (PS) -> 1 slave (direct, no protocol converter) --
# SmartConnect reads PROTOCOL=AXI4LITE from packaged IP component.xml and
# handles AXI4->AXI4-Lite conversion internally.
create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 axi_smc
set_property -dict [list CONFIG.NUM_SI {1} CONFIG.NUM_MI {1}] [get_bd_cells axi_smc]

# -- axi_regs256 as packaged IP (not module reference) --
create_bd_cell -type ip -vlnv xilinx.com:user:axi_regs256:1.0 u_regs

# ── Clocks ────────────────────────────────────────────────────────────────────
connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] \
               [get_bd_pins zynq_ultra_ps_e_0/maxihpm0_lpd_aclk]
connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] \
               [get_bd_pins proc_sys_reset_0/slowest_sync_clk]
connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_resetn0] \
               [get_bd_pins proc_sys_reset_0/ext_reset_in]
connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] [get_bd_pins axi_smc/aclk]
connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] [get_bd_pins u_regs/s00_axi_aclk]

# ── Resets ────────────────────────────────────────────────────────────────────
connect_bd_net [get_bd_pins proc_sys_reset_0/peripheral_aresetn] \
               [get_bd_pins axi_smc/aresetn]
connect_bd_net [get_bd_pins proc_sys_reset_0/peripheral_aresetn] \
               [get_bd_pins u_regs/s00_axi_aresetn]

# ── AXI connections ───────────────────────────────────────────────────────────
connect_bd_intf_net [get_bd_intf_pins zynq_ultra_ps_e_0/M_AXI_HPM0_LPD] \
                    [get_bd_intf_pins axi_smc/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_smc/M00_AXI] \
                    [get_bd_intf_pins u_regs/S00_AXI]

# ── Address assignment ────────────────────────────────────────────────────────
# Auto-assign (Vivado resolves the actual segment name from component.xml),
# then force the u_regs segment to 0xA0000000.
# IMPORTANT: range MUST match the IP's own declared decode width
# (component.xml address block range), not an arbitrarily larger window --
# forcing a larger range than the slave declares causes SmartConnect address
# translation to collapse every write to offset 0 (verified experimentally:
# vanilla 4-register IP with range forced to 4KB only ever wrote reg0,
# regardless of target address; every other register silently stayed at 0).
assign_bd_address
foreach seg [get_bd_addr_segs -of_objects [get_bd_addr_spaces zynq_ultra_ps_e_0/Data]] {
    if {[string match "*u_regs*" $seg]} {
        set_property offset 0x80000000 $seg
        set_property range  0x00000400 $seg
        puts "INFO: Mapped $seg -> 0x80000000 (1KB, full 256-register axi_regs256 IP)"
    }
}

# ── Validate and save ─────────────────────────────────────────────────────────
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
puts ""
puts "INFO: Test on ZCU102 Linux:"
puts "INFO:   devmem2 0xa0000000          # read ping constant -> expect 0xA0100001"
puts "INFO:   devmem2 0xa0000004 w 0x1234 # write reg[1]"
puts "INFO:   devmem2 0xa0000004          # read back -> expect 0x00001234"
exit
