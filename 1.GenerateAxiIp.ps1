# 1.GenerateAxiIp.ps1 — Generate AXI4-Lite slave IP template via Vivado
# -------------------------------------------------------
# Requires . .\0.Setup.ps1 first.
#
# Output: $env:OUT_DIR\ip\axi_regs256_1_0\hdl\   <- generated HDL template
# Next  : customise rtl\axi_regs256_v1_0_S00_AXI.v, then run 2.BuildBitstream.ps1
# -------------------------------------------------------

if (-not $env:OUT_DIR)   { Write-Error "OUT_DIR is not set. Run:  . .\0.Setup.ps1"; exit 1 }
if (-not $env:VIVADO)    { Write-Error "VIVADO is not set. Run:  . .\0.Setup.ps1"; exit 1 }
if (-not $env:FPGA_PART) { Write-Error "FPGA_PART is not set. Run:  . .\0.Setup.ps1"; exit 1 }

$TclScript = "$PSScriptRoot\scripts\gen_axi_slave_ip.tcl"
$OutIpDir  = "$env:OUT_DIR\ip"

if (-not (Test-Path $env:VIVADO)) { Write-Error "Vivado not found: $env:VIVADO"; exit 1 }
if (-not (Test-Path $TclScript))  { Write-Error "TCL script not found: $TclScript"; exit 1 }

Write-Host "=== Generating AXI4-Lite slave IP template ===" -ForegroundColor Cyan
Write-Host "  Part   : $env:FPGA_PART"
Write-Host "  Output : $OutIpDir"

# Pass OUT_DIR and FPGA_PART into TCL via -tclargs
cmd /c "`"$env:VIVADO`" -mode batch -source `"$TclScript`" -tclargs `"$OutIpDir`" `"$env:FPGA_PART`""

if ($LASTEXITCODE -eq 0) {
    Write-Host "=== Done ===" -ForegroundColor Green
    Write-Host "  HDL template : $OutIpDir\axi_regs256_1_0\hdl\"
    Write-Host "  Next: customise rtl\axi_regs256_v1_0_S00_AXI.v then run 2.BuildBitstream.ps1"
} else {
    Write-Host "ERROR: Vivado failed (exit $LASTEXITCODE)" -ForegroundColor Red
    exit $LASTEXITCODE
}
