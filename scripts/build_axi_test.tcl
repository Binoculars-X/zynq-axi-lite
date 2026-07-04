# build_axi_test.tcl
# Minimal AXI4-Lite loopback test for ZCU102.
#
# Architecture:
#   PS M_AXI_HPM0_FPD (ARM @ 0xA0000000)
#       -> SmartConnect
#       -> axi_protocol_converter (AXI4 full -> AXI4-Lite)
#       -> axi_regs256 (256 x 32-bit loopback registers)
#
# No ILA, no transformer RTL, no ROMs.
# Synth ~5 min, impl+bitstream ~15 min.
#
# Usage (from neuro-fabric root or repo root):
#   vivado -mode batch -source C:/repos/_Neuro/axi-test/scripts/build_axi_test.tcl
#
# Outputs: C:/repos/_Neuro/axi-test/out/
#   axi_test.bit   -- program to ZCU102
#   axi_test.xsa

# ── Short output path to avoid Windows 260-char limit ────────────────────────
set OutDir  "C:/repos/_Neuro/axi-test/out"
set ProjDir "$OutDir/vivado_proj"
set BdName  "axi_test_bd"
set IpRepo  "C:/repos/_Neuro/axi-test/out/ip"

file mkdir $OutDir

# ── Create project ────────────────────────────────────────────────────────────
create_project axi_test $ProjDir -part xczu9eg-ffvb1156-2-e -force
set_property board_part xilinx.com:zcu102:3.4 [current_project]

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
    CONFIG.PSU__USE__M_AXI_GP0                  {1}   \
    CONFIG.PSU__MAXIGP0__DATA_WIDTH             {32}  \
    CONFIG.PSU__USE__M_AXI_GP1                  {0}   \
    CONFIG.PSU__USE__M_AXI_GP2                  {0}   \
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
               [get_bd_pins zynq_ultra_ps_e_0/maxihpm0_fpd_aclk]
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
connect_bd_intf_net [get_bd_intf_pins zynq_ultra_ps_e_0/M_AXI_HPM0_FPD] \
                    [get_bd_intf_pins axi_smc/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_smc/M00_AXI] \
                    [get_bd_intf_pins u_regs/S00_AXI]

# ── Address assignment ────────────────────────────────────────────────────────
# Auto-assign (Vivado resolves the actual segment name from component.xml),
# then force the u_regs segment to 0xA0000000.
assign_bd_address
foreach seg [get_bd_addr_segs -of_objects [get_bd_addr_spaces zynq_ultra_ps_e_0/Data]] {
    if {[string match "*u_regs*" $seg]} {
        set_property offset 0xA0000000 $seg
        set_property range  0x00001000 $seg
        puts "INFO: Mapped $seg -> 0xA0000000 (4KB)"
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
