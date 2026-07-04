# 5.RunDevmemTest.ps1 — Run AXI4-Lite loopback tests on ZCU102 over SSH
# -------------------------------------------------------
# Requires . .\0.Setup.ps1 first.
# Board must be booted into PetaLinux and reachable at $env:BOARD_IP.
# One SSH session — you will be prompted for password once.
# -------------------------------------------------------

if (-not $env:BOARD_IP)   { Write-Error "BOARD_IP is not set. Run:  . .\0.Setup.ps1"; exit 1 }
if (-not $env:BOARD_USER) { Write-Error "BOARD_USER is not set. Run:  . .\0.Setup.ps1"; exit 1 }

Write-Host "=== AXI4-Lite loopback tests on ${env:BOARD_USER}@${env:BOARD_IP} ===" -ForegroundColor Cyan
Write-Host "(enter password when prompted)"

# All test commands run in a single SSH session.
# Results are prefixed so we can parse PASS/FAIL locally.
$remoteScript = @'
set -e
DM="sudo busybox devmem"

echo "RESULT:iomem:$(cat /proc/iomem | grep -i a0000 || echo MISSING)"

echo "RESULT:ping:$($DM 0xa0000000)"

$DM 0xa0000004 w 0x12345678
echo "RESULT:loopback:$($DM 0xa0000004)"

$DM 0xa0000008 w 0xFFFFFFFF
$DM 0xa0000008 b 0xAB
echo "RESULT:byteen:$($DM 0xa0000008)"

$DM 0xa00003f8 w 0xDEADBEEF
$DM 0xa00003fc w 0xCAFEBABE
echo "RESULT:bound254:$($DM 0xa00003f8)"
echo "RESULT:bound255:$($DM 0xa00003fc)"
'@

$output = & ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 `
    "${env:BOARD_USER}@${env:BOARD_IP}" $remoteScript

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
$iomem = ($lines | Where-Object { $_ -match "^RESULT:iomem:" }) -replace "^RESULT:iomem:", ""
Write-Host "  iomem : $iomem"

$failed += Check "ping"    $lines "0xA0100001"
$failed += Check "loopback" $lines "0x12345678"
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
