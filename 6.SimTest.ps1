# 6.SimTest.ps1 — Compile and simulate axi_regs256 testbench using XSim
# -------------------------------------------------------
# Requires . .\0.Setup.ps1 first (uses $env:VIVADO to locate XSim tools).
# No board needed — pure RTL simulation.
#
# Output: xsim waveform + pass/fail printed to console
# -------------------------------------------------------

if (-not $env:VIVADO) { Write-Error "VIVADO is not set. Run:  . .\0.Setup.ps1"; exit 1 }

# Derive XSim tool paths from VIVADO env var (same bin dir)
$BinDir = Split-Path $env:VIVADO
$Xvlog  = Join-Path $BinDir "xvlog.bat"
$Xelab  = Join-Path $BinDir "xelab.bat"
$Xsim   = Join-Path $BinDir "xsim.bat"

foreach ($tool in $Xvlog, $Xelab, $Xsim) {
    if (-not (Test-Path $tool)) { Write-Error "XSim tool not found: $tool"; exit 1 }
}

$RtlFile = "$PSScriptRoot\rtl\axi_regs256.v"
$TbFile  = "$PSScriptRoot\tb\tb_axi_regs256.v"
$Top     = "tb_axi_regs256"
$SimName = "${Top}_sim"

Push-Location $PSScriptRoot

Write-Host "=== Compiling RTL + TB ===" -ForegroundColor Cyan
& $Xvlog $RtlFile $TbFile
if ($LASTEXITCODE -ne 0) { Write-Error "xvlog failed"; Pop-Location; exit 1 }

Write-Host "=== Elaborating ===" -ForegroundColor Cyan
& $Xelab -debug typical $Top -s $SimName
if ($LASTEXITCODE -ne 0) { Write-Error "xelab failed"; Pop-Location; exit 1 }

Write-Host "=== Running simulation ===" -ForegroundColor Cyan
$out = & $Xsim $SimName --runall 2>&1
$out | Select-Object -Last 40

Pop-Location

Write-Host ""
if ($out -match "PASS") {
    Write-Host "=== SIMULATION PASSED ===" -ForegroundColor Green
} elseif ($out -match "FAIL") {
    Write-Host "=== SIMULATION FAILED ===" -ForegroundColor Red
    exit 1
} else {
    Write-Host "=== Simulation complete (check output above) ===" -ForegroundColor Yellow
}
Write-Host "  VCD: $PSScriptRoot\tb_axi_regs256.vcd" -ForegroundColor DarkGray
