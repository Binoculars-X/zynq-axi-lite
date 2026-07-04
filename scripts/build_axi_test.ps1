# build_axi_test.ps1
# Builds the axi-test loopback bitstream using Vivado 2026.1.
# Output: C:/axtest/out/axi_test.bit
#
# Usage: .\build_axi_test.ps1

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$TclScript = "$ScriptDir\build_axi_test.tcl"
$Vivado    = "C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat"

if (-not (Test-Path $Vivado))    { Write-Error "Vivado 2026.1 not found: $Vivado"; exit 1 }
if (-not (Test-Path $TclScript)) { Write-Error "TCL script not found: $TclScript"; exit 1 }

Write-Host "=== Building axi-test loopback bitstream (~20 min) ===" -ForegroundColor Cyan

Push-Location $ScriptDir
cmd /c "`"$Vivado`" -mode batch -source `"$TclScript`""
$ExitCode = $LASTEXITCODE
Pop-Location

if ($ExitCode -eq 0) {
    Write-Host "=== Build complete ===" -ForegroundColor Green
    Write-Host "Bitstream : C:\repos\_Neuro\axi-test\out\axi_test.bit"
    Write-Host "XSA       : C:\repos\_Neuro\axi-test\out\axi_test.xsa"
} else {
    Write-Host "ERROR: Vivado build failed (exit code $ExitCode) -- check C:\repos\_Neuro\axi-test\out\vivado_proj\axi_test.runs\" -ForegroundColor Red
    exit $ExitCode
}
