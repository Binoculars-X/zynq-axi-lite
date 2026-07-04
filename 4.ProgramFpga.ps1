# 4.ProgramFpga.ps1 — Program ZCU102 with the AXI4-Lite bitstream via JTAG
# -------------------------------------------------------
# Requires . .\0.Setup.ps1 first.
# Requires step 2 completed — bitstream must exist in $env:OUT_DIR
# Board must be powered on and connected via JTAG (USB cable).
# -------------------------------------------------------

if (-not $env:OUT_DIR)   { Write-Error "OUT_DIR is not set. Run:  . .\0.Setup.ps1"; exit 1 }
if (-not $env:VIVADO)    { Write-Error "VIVADO is not set. Run:  . .\0.Setup.ps1"; exit 1 }
if (-not $env:JTAG_URL)  { Write-Error "JTAG_URL is not set. Run:  . .\0.Setup.ps1"; exit 1 }

$TclScript = "$PSScriptRoot\scripts\program_axi_test.tcl"
$BitFile   = "$env:OUT_DIR\axi_test.bit"

if (-not (Test-Path $env:VIVADO))  { Write-Error "Vivado not found: $env:VIVADO"; exit 1 }
if (-not (Test-Path $TclScript))   { Write-Error "TCL script not found: $TclScript"; exit 1 }
if (-not (Test-Path $BitFile))     { Write-Error "Bitstream not found: $BitFile`nRun 2.BuildBitstream.ps1 first."; exit 1 }

Write-Host "=== Programming ZCU102 via JTAG ===" -ForegroundColor Cyan
Write-Host "  Bitstream : $BitFile"
Write-Host "  JTAG      : $env:JTAG_URL"

cmd /c "`"$env:VIVADO`" -mode batch -source `"$TclScript`" -tclargs `"$BitFile`" `"$env:JTAG_URL`""

if ($LASTEXITCODE -eq 0) {
    Write-Host "=== Programming complete ===" -ForegroundColor Green
} else {
    Write-Host "ERROR: Vivado programming failed (exit $LASTEXITCODE)" -ForegroundColor Red
    exit $LASTEXITCODE
}
