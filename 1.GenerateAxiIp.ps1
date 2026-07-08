# 1.GenerateAxiIp.ps1 — Generate AXI4-Lite slave IP template via Vivado
# -------------------------------------------------------
# Requires . .\0.Setup.ps1 first.
#
# Output: $env:OUT_DIR\ip\axi_regs256_1_0\hdl\   <- generated HDL template
# Next  : customise rtl\axi_regs256_v1_0_S00_AXI.v, then run 2.BuildBitstream.ps1
# -------------------------------------------------------

if (-not $env:OUT_DIR)      { Write-Error "OUT_DIR is not set. Run:  . .\0.Setup.ps1"; exit 1 }
if (-not $env:VIVADO_IP_GEN){ Write-Error "VIVADO_IP_GEN is not set. Run:  . .\0.Setup.ps1"; exit 1 }
if (-not $env:FPGA_PART)    { Write-Error "FPGA_PART is not set. Run:  . .\0.Setup.ps1"; exit 1 }

$TclScript = "$PSScriptRoot\scripts\gen_axi_slave_ip.tcl"
$OutIpDir  = "$env:OUT_DIR\ip"

if (-not (Test-Path $env:VIVADO_IP_GEN)) { Write-Error "Vivado (IP gen) not found: $env:VIVADO_IP_GEN"; exit 1 }
if (-not (Test-Path $TclScript))  { Write-Error "TCL script not found: $TclScript"; exit 1 }

Write-Host "=== Generating AXI4-Lite slave IP template ===" -ForegroundColor Cyan
Write-Host "  Vivado : $env:VIVADO_IP_GEN"
Write-Host "  Part   : $env:FPGA_PART"
Write-Host "  Output : $OutIpDir"

# Pass OUT_DIR and FPGA_PART into TCL via -tclargs
cmd /c "`"$env:VIVADO_IP_GEN`" -mode batch -source `"$TclScript`" -tclargs `"$OutIpDir`" `"$env:FPGA_PART`""

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Vivado failed (exit $LASTEXITCODE)" -ForegroundColor Red
    exit $LASTEXITCODE
}

# ── Post-process: patch generated IP files AFTER Vivado exits ─────────────────
# Vivado may rewrite files after the TCL exit, so patches must run here in PS.
$HdlDir  = "$OutIpDir\axi_regs256_1_0\hdl"
$XmlFile = "$OutIpDir\axi_regs256_1_0\component.xml"

# 1. Patch wrapper: C_S00_AXI_ADDR_WIDTH default 4 -> 10
$Wrapper = "$HdlDir\axi_regs256.v"
if (Test-Path $Wrapper) {
    $txt = [System.IO.File]::ReadAllText($Wrapper)
    $txt = $txt -replace '(C_S00_AXI_ADDR_WIDTH\s*=\s*)4\b', '${1}10'
    [System.IO.File]::WriteAllText($Wrapper, $txt, [System.Text.Encoding]::ASCII)
    Write-Host "  Patched wrapper ADDR_WIDTH 4->10"
}

# 2. Patch component.xml: range value 4 -> 10
if (Test-Path $XmlFile) {
    $txt = [System.IO.File]::ReadAllText($XmlFile)
    $txt = $txt -replace '(rangeType="long">)4(</spirit:value>)', '${1}10${2}'
    [System.IO.File]::WriteAllText($XmlFile, $txt, [System.Text.Encoding]::UTF8)
    Write-Host "  Patched component.xml ADDR_WIDTH 4->10"
}

# 3. Replace generated slave stub with custom RTL
$CustomRtl = "$PSScriptRoot\rtl\axi_regs256.v"
$GenHdl    = "$HdlDir\axi_regs256_v1_0_S00_AXI.v"
if ((Test-Path $CustomRtl) -and (Test-Path $GenHdl)) {
    Copy-Item -Force $CustomRtl $GenHdl
    Write-Host "  Copied rtl\axi_regs256.v -> $GenHdl"
} else {
    Write-Warning "Custom RTL not found at $CustomRtl"
}

Write-Host "=== Done ===" -ForegroundColor Green
Write-Host "  HDL : $HdlDir\"
Write-Host "  Next: run 2.BuildBitstream.ps1"
