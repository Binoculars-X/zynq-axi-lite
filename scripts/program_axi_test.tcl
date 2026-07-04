# program_axi_test.tcl
# Programs ZCU102 with the axi-test loopback bitstream via JTAG.
# Usage: vivado.bat -mode batch -source program_axi_test.tcl

set BitFile "C:/repos/_Neuro/axi-test/out/axi_test.bit"

if {![file exists $BitFile]} {
    puts "ERROR: Bitfile not found: $BitFile"
    puts "       Run build_axi_test.ps1 first."
    exit 1
}

puts "INFO: Programming $BitFile..."

open_hw_manager
connect_hw_server -url localhost:3121
open_hw_target localhost:3121/xilinx_tcf/Digilent/210308BED04A

set dev [lindex [get_hw_devices] 0]
current_hw_device $dev
refresh_hw_device $dev

set_property PROGRAM.FILE $BitFile $dev
program_hw_devices $dev

after 500
refresh_hw_device $dev

puts "INFO: Programming complete."
close_hw_manager
exit 0
