# sim_axi_test.ps1
# Compile and simulate axi_regs256 testbench using XSim (Vivado 2025.2).
# Run from any directory -- paths are relative to this script.
#
# Usage: .\sim_axi_test.ps1

$RepoRoot = Split-Path -Parent $PSScriptRoot
$Xvlog    = "C:\AMDDesignTools\2025.2\Vivado\bin\xvlog.bat"
$Xelab    = "C:\AMDDesignTools\2025.2\Vivado\bin\xelab.bat"
$Xsim     = "C:\AMDDesignTools\2025.2\Vivado\bin\xsim.bat"

$RtlFile = "$RepoRoot\rtl\axi_regs256.v"
$TbFile  = "$RepoRoot\tb\tb_axi_regs256.v"
$Top     = "tb_axi_regs256"

Push-Location $RepoRoot

Write-Host "=== Compiling RTL + TB ===" -ForegroundColor Cyan
& $Xvlog $RtlFile $TbFile
if ($LASTEXITCODE -ne 0) { Write-Error "xvlog failed"; Pop-Location; exit 1 }

Write-Host "=== Elaborating ===" -ForegroundColor Cyan
& $Xelab -debug typical $Top -s "${Top}_sim"
if ($LASTEXITCODE -ne 0) { Write-Error "xelab failed"; Pop-Location; exit 1 }

Write-Host "=== Running simulation ===" -ForegroundColor Cyan
& $Xsim "${Top}_sim" --runall 2>&1 | Select-Object -Last 30

Pop-Location

Write-Host ""
Write-Host "VCD trace: $RepoRoot\tb_axi_regs256.vcd" -ForegroundColor DarkGray
