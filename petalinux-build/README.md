# PetaLinux Build — ZCU102 gen00

Builds `BOOT.BIN` and `image.ub` for the ZCU102 ARM training setup.
The generated images configure the PS correctly for HPM0_FPD AXI access at `0xA0000000`.

---

## Prerequisites

### 1 — Docker image (one-time build)

```powershell
cd C:\repos\_Neuro\neuro-fabric\fpga\petalinux-build
docker build -t petalinux-zcu102:2026.1 .
```

Requires `petalinux-v2026.1-06061130-installer.run` in this directory (see below).

### 2 — Required files (gitignored — download separately)

| File | Size | Where to get it |
|------|------|-----------------|
| `petalinux-v2026.1-06061130-installer.run` | ~8 GB | [AMD Downloads](https://www.xilinx.com/support/download/index.html/content/xilinx/en/downloadNav/embedded-design-tools.html) → PetaLinux 2026.1 |
| `xilinx-zcu102-v2026.1-06092129.bsp` | ~2 GB | Same page → Board Support Packages → ZCU102 |

Both are listed under **PetaLinux Tools 2026.1** on the AMD download page.
An AMD/Xilinx account is required (free).

---

## Rebuild workflow

After a new Vivado BD build produces a new XSA:

```powershell
cd C:\repos\_Neuro\neuro-fabric\fpga\projects\gen00_train
.\rebuild_petalinux.ps1
```

The script reads the XSA from:
```
fpga/scripts/transformer_train_zcu102_axi_bd_out/transformer_train_zcu102_axi_bd.xsa
```

Outputs land in `C:\repos\_Neuro\temp\petalinux-output\`:
- `BOOT.BIN` — copy to FAT32 partition of SD card
- `image.ub` — copy to FAT32 partition of SD card
- `petalinux-sdimage.wic` — full SD card image (flash with Rufus/Etcher as alternative)

---

## SD card update (after rebuild)

1. Copy `BOOT.BIN` and `image.ub` to the FAT32 partition of the ZCU102 SD card
2. Safely eject, insert into board, power on
3. Program bitstream via JTAG: `.\program_board.tcl`
4. Run hop checks: `ssh petalinux@192.168.0.93 "sudo /tmp/arm_train --corpus /tmp --steps 1 --log 1"`

---

## What this build does

- Creates a PetaLinux project from template (XSA flow)
- Imports the BD XSA → generates correct FSBL with `psu_i2c_0` and HPM0_FPD enabled
- Builds kernel, rootfs (with openssh), U-Boot, FSBL, PMU firmware
- Packages `BOOT.BIN` (FSBL + PMU + TF-A + U-Boot) without embedded bitstream
  (bitstream is programmed separately via JTAG using `program_board.tcl`)

---

## Key history

| Date | Event |
|------|-------|
| 2026-06-30 | First BD build — HOP1 + HOP2 verified on board |
| 2026-07-01 | Added `scratch_reg` + `GEN00_VERSION` to `transformer_train.sv` for HOP3/HOP4 |
| 2026-07-01 | BD TCL updated to enable `psu_i2c_0` (MIO 14/15) — required for FSBL build |
| 2026-07-01 | PetaLinux rebuild succeeded — new `BOOT.BIN` + `image.ub` generated |
