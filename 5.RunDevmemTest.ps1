# 5.RunDevmemTest.ps1 — Run AXI4-Lite loopback tests on ZCU102 over SSH
# -------------------------------------------------------
# Requires . .\0.Setup.ps1 first.
# Board must be booted into PetaLinux and reachable at $env:BOARD_IP.
# -------------------------------------------------------

if (-not $env:BOARD_IP)   { Write-Error "BOARD_IP is not set. Run:  . .\0.Setup.ps1"; exit 1 }
if (-not $env:BOARD_USER) { Write-Error "BOARD_USER is not set. Run:  . .\0.Setup.ps1"; exit 1 }

$SSH = "ssh", "-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=NUL", "${env:BOARD_USER}@${env:BOARD_IP}"
$failed = 0

function Ssh-Run([string]$cmd) {
    $out = (& $SSH[0] $SSH[1..($SSH.Length-1)] $cmd 2>&1)
    # strip SSH warning lines, keep only the last non-empty line (the devmem result)
    return ($out | Where-Object { $_ -notmatch "^Warning:" -and $_.Trim() -ne "" } | Select-Object -Last 1)
}

function Check([string]$name, [string]$val, [string]$expected) {
    if ($val.Trim() -eq $expected) {
        Write-Host "  PASS  $name : $val" -ForegroundColor Green
        return 0
    } else {
        Write-Host "  FAIL  $name : got '$($val.Trim())'  expected '$expected'" -ForegroundColor Red
        return 1
    }
}

Write-Host "=== AXI4-Lite loopback tests on ${env:BOARD_USER}@${env:BOARD_IP} ===" -ForegroundColor Cyan
Write-Host ""

# reg0 write/read loopback
Ssh-Run "sudo busybox devmem 0xa0000000 w 0x12345678" | Out-Null
$r = Ssh-Run "sudo busybox devmem 0xa0000000"
$failed += Check "reg0" $r "0x12345678"

# reg1 write/read loopback
Ssh-Run "sudo busybox devmem 0xa0000004 w 0xDEADBEEF" | Out-Null
$r = Ssh-Run "sudo busybox devmem 0xa0000004"
$failed += Check "reg1" $r "0xDEADBEEF"

# byte-enable: fill then partial byte write
Ssh-Run "sudo busybox devmem 0xa0000008 w 0xFFFFFFFF" | Out-Null
Ssh-Run "sudo busybox devmem 0xa0000008 b 0xAB"       | Out-Null
$r = Ssh-Run "sudo busybox devmem 0xa0000008"
$failed += Check "byteen" $r "0xFFFFFFAB"

# boundary reg254
Ssh-Run "sudo busybox devmem 0xa00003f8 w 0xDEADBEEF" | Out-Null
$r = Ssh-Run "sudo busybox devmem 0xa00003f8"
$failed += Check "bound254" $r "0xDEADBEEF"

# boundary reg255
Ssh-Run "sudo busybox devmem 0xa00003fc w 0xCAFEBABE" | Out-Null
$r = Ssh-Run "sudo busybox devmem 0xa00003fc"
$failed += Check "bound255" $r "0xCAFEBABE"

Write-Host ""
if ($failed -eq 0) {
    Write-Host "=== ALL TESTS PASSED ===" -ForegroundColor Green
} else {
    Write-Host "=== $failed TEST(S) FAILED ===" -ForegroundColor Red
    exit 1
}


Write-Host "=== AXI4-Lite loopback tests on ${env:BOARD_USER}@${env:BOARD_IP} ==" -ForegroundColor Cyan

$remoteScript = @'
set -e
DM="sudo devmem"

# reg0 write/read loopback
$DM 0xa0000000 w 0x12345678
echo "RESULT:reg0:$($DM 0xa0000000)"

# reg1 write/read loopback
$DM 0xa0000004 w 0xDEADBEEF
echo "RESULT:reg1:$($DM 0xa0000004)"

# byte-enable test on reg2
$DM 0xa0000008 w 0xFFFFFFFF
$DM 0xa0000008 b 0xAB
echo "RESULT:byteen:$($DM 0xa0000008)"

# boundary registers (reg254, reg255)
$DM 0xa00003f8 w 0xDEADBEEF
$DM 0xa00003fc w 0xCAFEBABE
echo "RESULT:bound254:$($DM 0xa00003f8)"
echo "RESULT:bound255:$($DM 0xa00003fc)"
'@

$output = ($remoteScript -replace "`r`n", "`n") | & ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL `
    "${env:BOARD_USER}@${env:BOARD_IP}" bash

if ($LASTEXITCODE -ne 0) {
    Write-Error "SSH connection failed (exit $LASTEXITCODE)"
    exit 1
}

# ── Parse results ─────────────────────────────────────────────────────────────
function Check($name, $lines, $expected) {
    $line = $lines | Where-Object { $_ -match "^RESULT:${name}:" } | Select-Object -First 1
    $val  = ($line -replace "^RESULT:${name}:", "").Trim()
    if ($val -match [regex]::Escape($expected)) {
        Write-Host "  PASS  $name : $val" -ForegroundColor Green
        return 0
    } else {
        Write-Host "  FAIL  $name : got '$val'  expected '$expected'" -ForegroundColor Red
        return 1
    }
}

$lines  = $output -split "`n"
$failed = 0

Write-Host ""
$failed += Check "reg0"    $lines "0x12345678"
$failed += Check "reg1"    $lines "0xDEADBEEF"
$failed += Check "byteen"  $lines "0xFFFFFFAB"
$failed += Check "bound254" $lines "0xDEADBEEF"
$failed += Check "bound255" $lines "0xCAFEBABE"

Write-Host ""
if ($failed -eq 0) {
    Write-Host "=== ALL TESTS PASSED ===" -ForegroundColor Green
} else {
    Write-Host "=== $failed TEST(S) FAILED ===" -ForegroundColor Red
    exit 1
}
