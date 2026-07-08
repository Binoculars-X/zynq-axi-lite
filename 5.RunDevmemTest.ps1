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

function Check([string]$name, [string]$op, [string]$val, [string]$expected) {
    if ($val.Trim() -eq $expected) {
        Write-Host "  PASS  $name [$op] : $val" -ForegroundColor Green
        return 0
    } else {
        Write-Host "  FAIL  $name [$op] : got '$($val.Trim())'  expected '$expected'" -ForegroundColor Red
        return 1
    }
}

Write-Host "=== AXI4-Lite loopback tests on ${env:BOARD_USER}@${env:BOARD_IP} ===" -ForegroundColor Cyan
Write-Host ""

# reg0 is hardwired PING_CONST 0xA0100001 (read-only health check -- write is ignored)
$r = Ssh-Run "sudo busybox devmem 0x80000000"
$failed += Check "reg0   0x80000000" "read" $r "0xA0100001"

# reg1 write/read loopback
Ssh-Run "sudo busybox devmem 0x80000004 w 0xDEADBEEF" | Out-Null
$r = Ssh-Run "sudo busybox devmem 0x80000004"
$failed += Check "reg1   0x80000004" "write/read" $r "0xDEADBEEF"

# byte-enable: fill then partial byte write
Ssh-Run "sudo busybox devmem 0x80000008 w 0xFFFFFFFF" | Out-Null
Ssh-Run "sudo busybox devmem 0x80000008 b 0xAB"       | Out-Null
$r = Ssh-Run "sudo busybox devmem 0x80000008"
$failed += Check "byteen 0x80000008" "byte-write/read" $r "0xFFFFFFAB"

# boundary reg254 (offset 0x3f8, second-to-last register)
Ssh-Run "sudo busybox devmem 0x800003f8 w 0xDEADBEEF" | Out-Null
$r = Ssh-Run "sudo busybox devmem 0x800003f8"
$failed += Check "reg254 0x800003f8" "write/read" $r "0xDEADBEEF"

# boundary reg255 (offset 0x3fc, last register)
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
