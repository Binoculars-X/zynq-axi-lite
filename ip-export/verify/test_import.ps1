# test_import.ps1 — End-to-end consumability test for ip-export/axi_regs256.sv
# -------------------------------------------------------------------------
# Proves that the standalone artifact in this folder (axi_regs256.sv) can be
# packaged, built, programmed, and verified on hardware WITHOUT running any
# of the parent zynq-axi-lite repo's 0-5 build steps.
#
# Steps performed:
#   1. Package axi_regs256.sv as IP + build block design, synth, impl, bitstream
#      (via build_bd.tcl, which also runs package_ip.tcl logic internally)
#   2. Program the board over JTAG (via program_fpga.tcl)
#   3. Run devmem read/write/byte-enable/boundary tests over SSH
#
# Usage:
#   .\test_import.ps1
#
# All configuration lives in the SETTINGS block below -- edit the values
# there for your machine/board before running. No command-line parameters.
# -------------------------------------------------------------------------

# ── SETTINGS -- edit these for your machine/board ─────────────────────────────
$VivadoPath  = "C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat"
$FpgaPart    = "xczu9eg-ffvb1156-2-e"
$BoardPart   = "xilinx.com:zcu102:3.4"
$OutDir      = "$PSScriptRoot\out"
$BoardIp     = "192.168.0.93"
$BoardUser   = "petalinux"
$JtagUrl     = "localhost:3121/xilinx_tcf/Digilent/210308BED04A"

# Set to $true to skip that stage (e.g. reuse an existing bitstream/board state)
$SkipBuild   = $false
$SkipProgram = $false
$SkipTest    = $false

$ErrorActionPreference = "Stop"

Write-Host "=== ip-export consumability test ===" -ForegroundColor Cyan
Write-Host "  Vivado    : $VivadoPath"
Write-Host "  FpgaPart  : $FpgaPart"
Write-Host "  BoardPart : $BoardPart"
Write-Host "  OutDir    : $OutDir"

if (-not (Test-Path $VivadoPath)) {
    Write-Error "Vivado not found at $VivadoPath. Edit VivadoPath in the SETTINGS block at the top of this script."
}

# ── Step 1: package + build bitstream ─────────────────────────────────────────
if (-not $SkipBuild) {
    $TclScript = "$PSScriptRoot\build_bd.tcl"
    Write-Host "`n=== Step 1/3: Packaging IP + building bitstream (~20 min) ===" -ForegroundColor Cyan
    cmd /c "`"$VivadoPath`" -mode batch -source `"$TclScript`" -tclargs `"$OutDir`" `"$FpgaPart`" `"$BoardPart`""
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Build failed (exit $LASTEXITCODE)" -ForegroundColor Red
        exit $LASTEXITCODE
    }
    Write-Host "Build complete: $OutDir\axi_test.bit" -ForegroundColor Green
} else {
    Write-Host "`n=== Step 1/3: SKIPPED (-SkipBuild) ===" -ForegroundColor Yellow
}

# ── Step 2: program via JTAG ───────────────────────────────────────────────────
if (-not $SkipProgram) {
    if (-not $JtagUrl) { Write-Error "JtagUrl is not set. Edit the SETTINGS block at the top of this script." }

    $BitFile = "$OutDir\axi_test.bit"
    if (-not (Test-Path $BitFile)) { Write-Error "Bitstream not found: $BitFile" }

    $TclScript = "$PSScriptRoot\program_fpga.tcl"
    Write-Host "`n=== Step 2/3: Programming board via JTAG ===" -ForegroundColor Cyan
    Write-Host "  Bitstream : $BitFile"
    Write-Host "  JTAG      : $JtagUrl"
    cmd /c "`"$VivadoPath`" -mode batch -source `"$TclScript`" -tclargs `"$BitFile`" `"$JtagUrl`""
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Programming failed (exit $LASTEXITCODE)" -ForegroundColor Red
        exit $LASTEXITCODE
    }
    Write-Host "Programming complete." -ForegroundColor Green
} else {
    Write-Host "`n=== Step 2/3: SKIPPED (-SkipProgram) ===" -ForegroundColor Yellow
}

# ── Step 3: devmem test over SSH ───────────────────────────────────────────────
if (-not $SkipTest) {
    if (-not $BoardIp) { Write-Error "BoardIp is not set. Edit the SETTINGS block at the top of this script." }

    Write-Host "`n=== Step 3/3: devmem tests on ${BoardUser}@${BoardIp} ===" -ForegroundColor Cyan

    $SSH = "ssh", "-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=NUL", "${BoardUser}@${BoardIp}"
    $failed = 0

    function Ssh-Run([string]$cmd) {
        $out = (& $SSH[0] $SSH[1..($SSH.Length-1)] $cmd 2>&1)
        return ($out | Where-Object { $_ -notmatch "^Warning:" -and $_.Trim() -ne "" } | Select-Object -Last 1)
    }

    function Check([string]$name, [string]$op, [string]$val, [string]$expected) {
        if ($val.Trim() -eq $expected) {
            Write-Host "  PASS  $name [$op] : $val" -ForegroundColor Green
            return 0
        } else {
            Write-Host "  FAIL  $name [$op] : got '$($val.Trim())'  expected '$expected'" -ForegroundColor Red
            return 1
        }
    }

    # reg0 hardwired PING_CONST (read-only health check)
    $r = Ssh-Run "sudo busybox devmem 0x80000000"
    $failed += Check "reg0   0x80000000" "read" $r "0xA0100001"

    # reg1 write/read loopback
    Ssh-Run "sudo busybox devmem 0x80000004 w 0xDEADBEEF" | Out-Null
    $r = Ssh-Run "sudo busybox devmem 0x80000004"
    $failed += Check "reg1   0x80000004" "write/read" $r "0xDEADBEEF"

    # byte-enable
    Ssh-Run "sudo busybox devmem 0x80000008 w 0xFFFFFFFF" | Out-Null
    Ssh-Run "sudo busybox devmem 0x80000008 b 0xAB"       | Out-Null
    $r = Ssh-Run "sudo busybox devmem 0x80000008"
    $failed += Check "byteen 0x80000008" "byte-write/read" $r "0xFFFFFFAB"

    # boundary reg254/reg255
    Ssh-Run "sudo busybox devmem 0x800003f8 w 0xDEADBEEF" | Out-Null
    $r = Ssh-Run "sudo busybox devmem 0x800003f8"
    $failed += Check "reg254 0x800003f8" "write/read" $r "0xDEADBEEF"

    Ssh-Run "sudo busybox devmem 0x800003fc w 0xCAFEBABE" | Out-Null
    $r = Ssh-Run "sudo busybox devmem 0x800003fc"
    $failed += Check "reg255 0x800003fc" "write/read" $r "0xCAFEBABE"

    Write-Host ""
    if ($failed -eq 0) {
        Write-Host "=== ALL TESTS PASSED ===" -ForegroundColor Green
    } else {
        Write-Host "=== $failed TEST(S) FAILED ===" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "`n=== Step 3/3: SKIPPED (-SkipTest) ===" -ForegroundColor Yellow
}
