# RunAll.ps1 — Single-entry-point orchestration: IP gen -> build -> program -> test
# -------------------------------------------------------
# Runs the full reproducible pipeline in order, stopping immediately on the
# first failure. This is the recommended way to build/verify this repo from
# a clean checkout (rather than running 0-5 manually one at a time).
#
# Requires: 0.Setup.ps1 already configured with your board/JTAG values.
# Usage:
#   . .\0.Setup.ps1
#   .\RunAll.ps1
# -------------------------------------------------------

$ErrorActionPreference = "Stop"

if (-not $env:VIVADO) {
    Write-Error "Environment not configured. Run:  . .\0.Setup.ps1"
    exit 1
}

$steps = @(
    @{ Name = "Generate AXI4-Lite IP"; Script = ".\1.GenerateAxiIp.ps1" },
    @{ Name = "Build bitstream";       Script = ".\2.BuildBitstream.ps1" },
    @{ Name = "Program FPGA";          Script = ".\4.ProgramFpga.ps1" },
    @{ Name = "Run devmem tests";      Script = ".\5.RunDevmemTest.ps1" }
)

foreach ($step in $steps) {
    Write-Host ""
    Write-Host "=== $($step.Name) ($($step.Script)) ===" -ForegroundColor Cyan
    & $step.Script
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "=== PIPELINE FAILED at: $($step.Name) ===" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "=== PIPELINE COMPLETE — all steps passed ===" -ForegroundColor Green
