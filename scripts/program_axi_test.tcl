# program_axi_test.tcl
# Programs ZCU102 with the axi-test loopback bitstream via JTAG.
# Usage: vivado.bat -mode batch -source program_axi_test.tcl

set BitFile  [string map {\\ /} [lindex $argv 0]]
set JtagUrl  [lindex $argv 1]

if {$BitFile eq "" || $JtagUrl eq ""} {
    puts "ERROR: Usage: vivado -mode batch -source program_axi_test.tcl -tclargs <bit_file> <jtag_url>"
    exit 1
}

if {![file exists $BitFile]} {
    puts "ERROR: Bitfile not found: $BitFile"
    puts "       Run 2.BuildBitstream.ps1 first."
    exit 1
}

puts "INFO: Programming $BitFile..."

open_hw_manager
# Extract "host:port" from the full target URL (first segment before the first /)
regexp {^([^/]+)} $JtagUrl -> HwServer
connect_hw_server -url $HwServer
open_hw_target $JtagUrl

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
