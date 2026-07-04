# 2.BuildBitstream.ps1 — Synthesise + implement AXI4-Lite loopback bitstream
# -------------------------------------------------------
# Requires . .\0.Setup.ps1 first.
# Requires step 1 completed — IP must exist in $env:OUT_DIR\ip
#
# Output:
#   $env:OUT_DIR\axi_test.bit   <- program to board via 4.ProgramFpga.ps1
#   $env:OUT_DIR\axi_test.xsa   <- used by 3.BuildPetaLinux.ps1
# -------------------------------------------------------

if (-not $env:OUT_DIR)    { Write-Error "OUT_DIR is not set. Run:  . .\0.Setup.ps1"; exit 1 }
if (-not $env:VIVADO)     { Write-Error "VIVADO is not set. Run:  . .\0.Setup.ps1"; exit 1 }
if (-not $env:FPGA_PART)  { Write-Error "FPGA_PART is not set. Run:  . .\0.Setup.ps1"; exit 1 }
if (-not $env:BOARD_PART) { Write-Error "BOARD_PART is not set. Run:  . .\0.Setup.ps1"; exit 1 }

$TclScript = "$PSScriptRoot\scripts\build_axi_test.tcl"
$IpRepo    = "$env:OUT_DIR\ip"

if (-not (Test-Path $env:VIVADO))  { Write-Error "Vivado not found: $env:VIVADO"; exit 1 }
if (-not (Test-Path $TclScript))   { Write-Error "TCL script not found: $TclScript"; exit 1 }
if (-not (Test-Path $IpRepo))      { Write-Error "IP repo not found: $IpRepo`nRun 1.GenerateAxiIp.ps1 first."; exit 1 }

Write-Host "=== Building AXI4-Lite loopback bitstream (~20 min) ===" -ForegroundColor Cyan
Write-Host "  Part      : $env:FPGA_PART"
Write-Host "  Board     : $env:BOARD_PART"
Write-Host "  Output    : $env:OUT_DIR"

# Pass OUT_DIR, IP repo, FPGA part and board part into TCL via -tclargs
cmd /c "`"$env:VIVADO`" -mode batch -source `"$TclScript`" -tclargs `"$env:OUT_DIR`" `"$IpRepo`" `"$env:FPGA_PART`" `"$env:BOARD_PART`""
$ExitCode = $LASTEXITCODE

if ($ExitCode -eq 0) {
    Write-Host "=== Build complete ===" -ForegroundColor Green
    Write-Host "  Bitstream : $env:OUT_DIR\axi_test.bit"
    Write-Host "  XSA       : $env:OUT_DIR\axi_test.xsa"
} else {
    Write-Host "ERROR: Vivado build failed (exit $ExitCode)" -ForegroundColor Red
    Write-Host "  Check logs in: $env:OUT_DIR\vivado_proj\axi_test.runs\" -ForegroundColor Red
    exit $ExitCode
}
