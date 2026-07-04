# 3.BuildPetaLinux.ps1 — Build PetaLinux SD card image via Docker
# -------------------------------------------------------
# Prerequisites:
#   1. Run . .\0.Setup.ps1  (sets $env:OUT_DIR, $env:PETALINUX_PROJECT)
#   2. Docker Desktop running with Linux containers
#   3. Docker image built: petalinux-zcu102:2026.1
#      (see petalinux-build/README.md for how to build the image)
#   4. Step 2 completed — XSA must exist in $env:OUT_DIR
#
# Output:
#   $env:OUT_DIR\petalinux-sdimage.wic   <- write to SD card with Rufus
#   $env:OUT_DIR\BOOT.BIN
#   $env:OUT_DIR\image.ub
#   $env:OUT_DIR\rootfs.tar.gz
# -------------------------------------------------------

$RepoRoot  = $PSScriptRoot
$BuildSh   = "$RepoRoot\petalinux-build\build.sh"
$XsaPath   = "$env:OUT_DIR\axi_test.xsa"
$OutDir    = $env:OUT_DIR

# ── Guard: require 0.Setup.ps1 to have been sourced ──────────────────────────
if (-not $env:OUT_DIR) {
    Write-Error "OUT_DIR is not set. Run:  . .\0.Setup.ps1"
    exit 1
}

# ── Guard: Docker must be running ─────────────────────────────────────────────
docker info 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Error "Docker is not running. Start Docker Desktop (Linux containers mode) and retry."
    exit 1
}

# ── Auto-build Docker image if missing ───────────────────────────────────────
$ImageTag    = "petalinux-zcu102:2026.1"
$PetaDir     = "$RepoRoot\petalinux-build"
$RunFile     = Get-ChildItem "$PetaDir\petalinux-v*.run" | Select-Object -First 1
$BspFile     = Get-ChildItem "$PetaDir\*.bsp"            | Select-Object -First 1

$ImageExists = docker images -q $ImageTag 2>&1
if (-not $ImageExists) {
    Write-Host "Docker image '$ImageTag' not found — building it now (~10-20 min)..." -ForegroundColor Yellow

    if (-not $RunFile) { Write-Error "PetaLinux installer (.run) not found in $PetaDir"; exit 1 }
    if (-not $BspFile) { Write-Error "ZCU102 BSP (.bsp) not found in $PetaDir"; exit 1 }

    Write-Host "  Installer : $($RunFile.Name)"
    Write-Host "  BSP       : $($BspFile.Name)"

    docker build -t $ImageTag $PetaDir

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Docker image build failed. Check output above."
        exit 1
    }
    Write-Host "Docker image built successfully." -ForegroundColor Green
} else {
    Write-Host "Docker image '$ImageTag' found." -ForegroundColor Green
}

# ── Guard: XSA must exist (produced by 2.BuildBitstream.ps1) ─────────────────
if (-not (Test-Path $XsaPath)) {
    Write-Error "XSA not found: $XsaPath`nRun 2.BuildBitstream.ps1 first."
    exit 1
}

if (-not (Test-Path $BuildSh)) {
    Write-Error "build.sh not found: $BuildSh"
    exit 1
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

# Convert Windows paths to Docker-compatible (forward slashes, /host/... via Docker Desktop)
$BuildShDocker = $BuildSh   -replace '\\', '/' -replace '^C:', '/c'
$XsaDocker     = $XsaPath   -replace '\\', '/' -replace '^C:', '/c'
$OutDocker     = $OutDir     -replace '\\', '/' -replace '^C:', '/c'

Write-Host "=== Building PetaLinux SD image (~30-60 min) ===" -ForegroundColor Cyan
Write-Host "  XSA    : $XsaPath"
Write-Host "  Output : $OutDir"

docker run --rm `
    -v "${BuildShDocker}:/home/builder/build.sh" `
    -v "${OutDocker}:/output" `
    -v "${XsaDocker}:/tmp/axi_test.xsa:ro" `
    petalinux-zcu102:2026.1

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Docker / PetaLinux build failed (exit $LASTEXITCODE)" -ForegroundColor Red
    exit $LASTEXITCODE
}

# ── Report output ─────────────────────────────────────────────────────────────
$Wic = Get-ChildItem -Path $OutDir -Filter "*.wic" | Select-Object -First 1

Write-Host ""
Write-Host "=== Build complete ===" -ForegroundColor Green
Write-Host "  BOOT.BIN  : $OutDir\BOOT.BIN"
Write-Host "  image.ub  : $OutDir\image.ub"
Write-Host "  rootfs    : $OutDir\rootfs.tar.gz"
if ($Wic) {
    Write-Host ""
    Write-Host "  SD image  : $($Wic.FullName)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To flash the SD card:" -ForegroundColor Cyan
    Write-Host "  1. Open Rufus (https://rufus.ie)"
    Write-Host "  2. Device     -> select your SD card"
    Write-Host "  3. Boot selection -> select the .wic file above"
    Write-Host "  4. Write mode -> DD Image"
    Write-Host "  5. Click START — this creates both FAT32 (boot) and ext4 (rootfs) partitions"
} else {
    Write-Warning "No .wic file found in $OutDir — check Docker build output above."
}
