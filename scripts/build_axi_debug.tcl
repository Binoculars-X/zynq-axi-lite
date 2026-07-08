# build_axi_debug.tcl
# Same as build_axi_test.tcl but with an ILA (Integrated Logic Analyzer)
# probing the S00_AXI write-address/write-data channel signals at the
# u_regs boundary, so we can observe on real hardware what AWADDR/WDATA/
# WSTRB values actually arrive at the slave during a devmem write.
#
# Usage:
#   vivado -mode batch -source build_axi_debug.tcl -tclargs <out_dir> <ip_repo> <fpga_part> <board_part>
#
# Outputs: <out_dir>/axi_debug.bit, <out_dir>/axi_debug.ltx

set OutDir   [string map {\\ /} [lindex $argv 0]]
set IpRepo   [string map {\\ /} [lindex $argv 1]]
set FpgaPart [lindex $argv 2]
set BoardPart [lindex $argv 3]

if {$OutDir eq "" || $FpgaPart eq "" || $BoardPart eq ""} {
    puts "ERROR: Usage: vivado -mode batch -source build_axi_debug.tcl -tclargs <out_dir> <ip_repo> <fpga_part> <board_part>"
    exit 1
}

set ProjDir "$OutDir/vivado_proj_debug"
set BdName  "axi_test_bd"

file mkdir $OutDir

create_project axi_test_debug $ProjDir -part $FpgaPart -force
set_property board_part $BoardPart [current_project]

set_property ip_repo_paths $IpRepo [current_project]
update_ip_catalog -rebuild

create_bd_design $BdName

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

create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_0

create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 axi_smc
set_property -dict [list CONFIG.NUM_SI {1} CONFIG.NUM_MI {1}] [get_bd_cells axi_smc]

create_bd_cell -type ip -vlnv xilinx.com:user:axi_regs256:1.0 u_regs

connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] \
               [get_bd_pins zynq_ultra_ps_e_0/maxihpm0_fpd_aclk]
connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] \
               [get_bd_pins proc_sys_reset_0/slowest_sync_clk]
connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_resetn0] \
               [get_bd_pins proc_sys_reset_0/ext_reset_in]
connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] [get_bd_pins axi_smc/aclk]
connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] [get_bd_pins u_regs/s00_axi_aclk]

connect_bd_net [get_bd_pins proc_sys_reset_0/peripheral_aresetn] \
               [get_bd_pins axi_smc/aresetn]
connect_bd_net [get_bd_pins proc_sys_reset_0/peripheral_aresetn] \
               [get_bd_pins u_regs/s00_axi_aresetn]

connect_bd_intf_net [get_bd_intf_pins zynq_ultra_ps_e_0/M_AXI_HPM0_FPD] \
                    [get_bd_intf_pins axi_smc/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_smc/M00_AXI] \
                    [get_bd_intf_pins u_regs/S00_AXI]

assign_bd_address
foreach seg [get_bd_addr_segs -of_objects [get_bd_addr_spaces zynq_ultra_ps_e_0/Data]] {
    if {[string match "*u_regs*" $seg]} {
        set_property offset 0xA0000000 $seg
        set_property range  0x00000080 $seg
        puts "INFO: Mapped $seg -> 0xA0000000 (128B)"
    }
}

# ── Debug: System ILA probing the u_regs S00_AXI interface directly ──────────
# system_ila natively supports AXI interface probes (captures
# AWADDR/AWVALID/AWREADY/WDATA/WSTRB/WVALID/WREADY/BRESP/BVALID/BREADY/etc.)
create_bd_cell -type ip -vlnv xilinx.com:ip:system_ila:1.1 u_ila_0
set_property -dict [list \
    CONFIG.C_NUM_MONITOR_SLOTS {1} \
    CONFIG.C_MON_TYPE {INTERFACE} \
    CONFIG.C_SLOT_0_INTF_TYPE {xilinx.com:interface:aximm_rtl:1.0} \
    CONFIG.C_DATA_DEPTH {4096} \
] [get_bd_cells u_ila_0]
connect_bd_net [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] [get_bd_pins u_ila_0/clk]
connect_bd_intf_net [get_bd_intf_pins u_ila_0/SLOT_0_AXI] [get_bd_intf_pins u_regs/S00_AXI]

validate_bd_design
save_bd_design

set WrapperFile [make_wrapper -files [get_files ${BdName}.bd] -top -force]
add_files -norecurse $WrapperFile
set_property top ${BdName}_wrapper [current_fileset]
update_compile_order -fileset sources_1

generate_target all [get_files ${BdName}.bd]

puts "INFO: Launching synthesis..."
set_property STEPS.SYNTH_DESIGN.ARGS.FLATTEN_HIERARCHY none [get_runs synth_1]
launch_runs synth_1 -jobs 4
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
    error "Synthesis failed: [get_property STATUS [get_runs synth_1]]"
}
puts "INFO: Synthesis complete."
open_run synth_1 -name synth_1

puts "INFO: Launching implementation..."
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    error "Implementation failed: [get_property STATUS [get_runs impl_1]]"
}
puts "INFO: Implementation complete."
open_run impl_1

write_bitstream -force "$OutDir/axi_debug.bit"
write_debug_probes -force "$OutDir/axi_debug.ltx"

puts "INFO: Done."
puts "INFO: Bitstream : $OutDir/axi_debug.bit"
puts "INFO: Probes    : $OutDir/axi_debug.ltx"
