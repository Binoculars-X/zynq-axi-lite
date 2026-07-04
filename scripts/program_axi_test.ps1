# program_axi_test.ps1
# Programs the ZCU102 with the axi-test loopback bitstream via JTAG.
# Uses Vivado 2025.2 hw_server (same as main transformer program_board.ps1).
#
# Usage: .\program_axi_test.ps1

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$TclScript = "$ScriptDir\program_axi_test.tcl"
$Vivado    = "C:\AMDDesignTools\2025.2\Vivado\bin\vivado.bat"

if (-not (Test-Path $Vivado))    { Write-Error "Vivado 2025.2 not found: $Vivado"; exit 1 }
if (-not (Test-Path $TclScript)) { Write-Error "TCL script not found: $TclScript"; exit 1 }

if (-not (Test-Path "C:\repos\_Neuro\axi-test\out\axi_test.bit")) {
    Write-Error "Bitstream not found: C:\repos\_Neuro\axi-test\out\axi_test.bit -- run build_axi_test.ps1 first"
    exit 1
}

Write-Host "Programming board via hw_server..." -ForegroundColor Cyan
& $Vivado -mode batch -source $TclScript
if ($LASTEXITCODE -ne 0) { Write-Error "Vivado programming failed (exit $LASTEXITCODE)"; exit $LASTEXITCODE }
Write-Host "Done." -ForegroundColor Green
