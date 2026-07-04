# gen_axi_slave_ip.ps1
# Generates a fresh AXI4-Lite peripheral template using Vivado 2026.1.
# Output: C:/axtest/ip/axi_regs256_1_0/hdl/
#
# Usage: .\gen_axi_slave_ip.ps1

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$TclScript = "$ScriptDir\gen_axi_slave_ip.tcl"
$Vivado    = "C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat"

if (-not (Test-Path $Vivado))    { Write-Error "Vivado 2026.1 not found: $Vivado"; exit 1 }
if (-not (Test-Path $TclScript)) { Write-Error "TCL script not found: $TclScript"; exit 1 }

Write-Host "=== Generating AXI4-Lite slave IP template ===" -ForegroundColor Cyan

cmd /c "`"$Vivado`" -mode batch -source `"$TclScript`""

if ($LASTEXITCODE -eq 0) {
    Write-Host "=== Done ===" -ForegroundColor Green
    Write-Host "HDL template : C:\repos\_Neuro\axi-test\out\ip\axi_regs256_1_0\hdl\"
    Write-Host "Next: copy S00_AXI.v into axi-test\rtl\ and add loopback register logic"
} else {
    Write-Host "ERROR: Vivado failed (exit $LASTEXITCODE)" -ForegroundColor Red
    exit $LASTEXITCODE
}
