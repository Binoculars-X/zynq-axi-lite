# 0.Setup.ps1 — Developer environment configuration
# -------------------------------------------------------
# Every developer who clones this repo MUST run this script once per shell
# session (or add it to their PowerShell profile).
#
# Copy this file, fill in the values for your machine, and run:
#   . .\0.Setup.ps1
# (dot-source so variables persist in the current shell)
# -------------------------------------------------------

# ── Vivado ────────────────────────────────────────────────────────────────────
# Full path to vivado.bat for your Vivado 2026.1 installation.
# AMD unified installer default: C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat
$env:VIVADO          = "C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat"

# ── Target device ─────────────────────────────────────────────────────────────
# Xilinx part number and Vivado board-part string for ZCU102.
# Change these if you target a different board.
$env:FPGA_PART       = "xczu9eg-ffvb1156-2-e"
$env:BOARD_PART      = "xilinx.com:zcu102:3.4"

# ── Output directory ──────────────────────────────────────────────────────────
# Where Vivado project, bitstream, and XSA are written.
# Relative to the repo root — works regardless of where the repo is cloned.
$env:OUT_DIR         = "$PSScriptRoot\out"

# ── Board access ──────────────────────────────────────────────────────────────
# IP address of the ZCU102 on your LAN (set a static IP on the board).
$env:BOARD_IP        = "192.168.0.93"

# JTAG target URL for Vivado hw_server.
# Find yours: open Vivado Hardware Manager, connect, and read the target path,
# or run: vivado -mode tcl -> connect_hw_server -> get_hw_targets
# Format: localhost:3121/xilinx_tcf/Digilent/<serial>
$env:JTAG_URL        = "localhost:3121/xilinx_tcf/Digilent/210308BED04A"

# SSH user for PetaLinux (default root; change if you added a non-root user).
$env:BOARD_USER      = "petalinux"

# ── Sanity check ──────────────────────────────────────────────────────────────
Write-Host "=== Environment ===" -ForegroundColor Cyan
Write-Host "  VIVADO          : $env:VIVADO"
Write-Host "  FPGA_PART       : $env:FPGA_PART"
Write-Host "  BOARD_PART      : $env:BOARD_PART"
Write-Host "  OUT_DIR         : $env:OUT_DIR"
Write-Host "  BOARD_IP        : $env:BOARD_IP"
Write-Host "  JTAG_URL        : $env:JTAG_URL"
Write-Host "  BOARD_USER      : $env:BOARD_USER"
if (-not (Test-Path $env:VIVADO)) {
    Write-Warning "VIVADO not found at $env:VIVADO -- update the path above."
} else {
    Write-Host "  Vivado OK" -ForegroundColor Green
}