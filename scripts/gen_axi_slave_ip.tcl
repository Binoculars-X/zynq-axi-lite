# gen_axi_slave_ip.tcl
# Generates a fresh AXI4-Lite peripheral template using Vivado 2025.2 IP packager.
# Output: C:/repos/_Neuro/axi-test/out/ip/axi_regs256_1_0/hdl/
#
# Usage:
#   vivado.bat -mode batch -source C:/repos/_Neuro/axi-test/scripts/gen_axi_slave_ip.tcl

# Args passed from 1.GenerateAxiIp.ps1 via -tclargs
set OutIpDir [string map {\\ /} [lindex $argv 0]]
set FpgaPart [lindex $argv 1]

if {$OutIpDir eq "" || $FpgaPart eq ""} {
    puts "ERROR: Usage: vivado -mode batch -source gen_axi_slave_ip.tcl -tclargs <out_ip_dir> <fpga_part>"
    exit 1
}

file mkdir $OutIpDir

# create_peripheral requires an open project -- use in-memory (no disk project needed)
create_project -in_memory -part $FpgaPart

# Create the peripheral definition
create_peripheral xilinx.com user axi_regs256 1.0 -dir $OutIpDir

# Add one AXI4-Lite slave interface, 32-bit data, 10-bit address (256 registers)
set periph [ipx::find_open_core xilinx.com:user:axi_regs256:1.0]
add_peripheral_interface S00_AXI \
    -interface_mode slave \
    -axi_type lite \
    $periph

# Generate the HDL template files
generate_peripheral -driver -bfm_example_design -debug_hw_example_design -force $periph

# Write the IP to disk
write_peripheral $periph

puts "INFO: IP generated at $OutIpDir/axi_regs256_1_0/"
puts "INFO: HDL template : $OutIpDir/axi_regs256_1_0/hdl/"
exit
