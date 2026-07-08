# capture_axi_debug.tcl
# Programs the debug bitstream (with System ILA on u_regs S00_AXI), arms
# the ILA to trigger on AWVALID, issues a real devmem write over SSH to the
# board while the ILA is armed, then uploads and dumps the capture to CSV.
#
# Usage:
#   vivado -mode batch -source capture_axi_debug.tcl -tclargs <bit_file> <ltx_file> <jtag_url> <csv_file>

set BitFile [string map {\\ /} [lindex $argv 0]]
set LtxFile [string map {\\ /} [lindex $argv 1]]
set JtagUrl [lindex $argv 2]
set CsvFile [string map {\\ /} [lindex $argv 3]]

open_hw_manager
regexp {^([^/]+)} $JtagUrl -> HwServer
connect_hw_server -url $HwServer
open_hw_target $JtagUrl

set dev [lindex [get_hw_devices] 0]
current_hw_device $dev
set_property PROGRAM.FILE $BitFile $dev
program_hw_devices $dev
refresh_hw_device -update_hw_probes true $dev
set_property PROBES.FILE $LtxFile $dev
refresh_hw_device $dev

set ila [lindex [get_hw_ilas -of_objects $dev] 0]
puts "INFO: Using ILA core: $ila"

set all_probes [get_hw_probes -of_objects $ila]
puts "INFO: Available probes:"
foreach p $all_probes { puts "  $p" }

set awvalid_probe [lindex [get_hw_probes -of_objects $ila -filter {NAME =~ *awvalid}] 0]
if {$awvalid_probe eq ""} {
    puts "ERROR: No AWVALID probe found"
    exit 1
}
puts "INFO: Trigger probe: $awvalid_probe"

set_property CONTROL.TRIGGER_POSITION 100 $ila
set_property CONTROL.TRIGGER_CONDITION AND $ila
set_property TRIGGER_COMPARE_VALUE eq1'b1 $awvalid_probe

run_hw_ila $ila
puts "INFO: ILA armed. Issuing remote write over SSH..."

# Issue the real write while the ILA is armed and waiting for AWVALID.
exec ssh -o StrictHostKeyChecking=no petalinux@192.168.0.93 "sudo busybox devmem 0xa0000004 w 0xDEADBEEF"

wait_on_hw_ila $ila
puts "INFO: ILA triggered. Uploading capture..."

set wave [upload_hw_ila_data $ila]
write_hw_ila_data -csv_file $CsvFile $wave -force
puts "INFO: Capture saved to $CsvFile"

close_hw_manager
exit 0
