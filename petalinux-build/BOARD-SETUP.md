# Board Setup — ZCU102 Post-Reflash

Run these steps every time a new PetaLinux SD image is flashed.
After completing this guide: `ssh`, `scp`, and `sudo` work with no password,
and `/data` (23 GB) is mounted and persists across reboots.

---

## Default credentials (after reflash)

| Field    | Value       |
|----------|-------------|
| User     | `petalinux` |
| Password | `petalinux` |
| IP       | 192.168.0.93 |

---

## Step 1 — Clear stale host key on PC (after every reflash)

```powershell
ssh-keygen -R 192.168.0.93
```

Without this, SSH will refuse to connect with a `WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED` error.

---

## Step 2 — Push SSH key to board (enter password once)

```powershell
# Generate key if not already present
ssh-keygen -t ed25519 -f "$HOME\.ssh\id_ed25519" -N '""'

# Push key — accepts new host key automatically, prompts for password once
type "$HOME\.ssh\id_ed25519.pub" | ssh -o StrictHostKeyChecking=accept-new petalinux@192.168.0.93 "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys && echo KEY_INSTALLED"
```

After this: `ssh petalinux@192.168.0.93` requires no password.

---

## Step 3 — Passwordless sudo (requires `-t` flag the first time)

```powershell
ssh -t petalinux@192.168.0.93 "echo 'petalinux ALL=(ALL) NOPASSWD: ALL' | sudo tee /etc/sudoers.d/petalinux && sudo chmod 440 /etc/sudoers.d/petalinux && echo SUDO_DONE"
```

Enter password `petalinux` at the prompt. After this: `sudo` requires no password.

---

## Step 4 — Mount `/data` partition (p3)

**After a full WIC reflash (Rufus DD mode): p3 is gone — follow the "first time" steps below.**
After a partial update (BOOT.BIN+image.ub copy only): p3 data survives but fstab is wiped.
In that case the system auto-mounts it at `/run/media/mmcblk0p3` — move it to `/data`:

```powershell
ssh petalinux@192.168.0.93 "sudo umount /run/media/mmcblk0p3 ; sudo mkdir -p /data ; echo '/dev/mmcblk0p3  /data  ext4  defaults  0  2' | sudo tee -a /etc/fstab ; sudo mount /data ; df -h /data"
```

Expected output: `/data` showing ~22 GB available.

### If p3 does not exist (first time on a new SD card)

```powershell
# Create p3 using all remaining space (run on board via SSH)
ssh petalinux@192.168.0.93 "printf 'n\np\n3\n12582920\n\nw\n' | sudo fdisk /dev/mmcblk0 ; echo PARTITION_WRITTEN"
# Reboot to let kernel re-read partition table
ssh petalinux@192.168.0.93 "sudo reboot"
# Wait ~30s, then format and mount
Start-Sleep 35
ssh petalinux@192.168.0.93 "sudo mkfs.ext4 -L data /dev/mmcblk0p3 && sudo mkdir -p /data && echo '/dev/mmcblk0p3  /data  ext4  defaults  0  2' | sudo tee -a /etc/fstab && sudo mount /data && df -h /data && echo DATA_READY"
```

---

## Step 5 — Verify everything works

```powershell
ssh petalinux@192.168.0.93 "sudo ls /data && df -h /data && echo ALL_GOOD"
```

Expected:
```
Filesystem      Size  Used Avail Use% Mounted on
/dev/mmcblk0p3   23G  2.0M   22G   0% /data
ALL_GOOD
```

---

## SD card partition layout

| Partition      | Size    | FS     | Mount      | Purpose         |
|----------------|---------|--------|------------|-----------------|
| `/dev/mmcblk0p1` | 2 GB  | FAT32  | `/boot`    | BOOT.BIN, image.ub |
| `/dev/mmcblk0p2` | 4 GB  | ext4   | `/`        | rootfs          |
| `/dev/mmcblk0p3` | ~23 GB | ext4  | `/data`    | training data, logs |

p3 start sector: **12582920** (immediately after p2 end at 12582919).

---

## Quick-reference: all 4 steps as one block

After clearing stale host key (`ssh-keygen -R 192.168.0.93`):

```powershell
# 1. Push SSH key
type "$HOME\.ssh\id_ed25519.pub" | ssh -o StrictHostKeyChecking=accept-new petalinux@192.168.0.93 "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys"

# 2. Passwordless sudo (enter password 'petalinux' once)
ssh -t petalinux@192.168.0.93 "echo 'petalinux ALL=(ALL) NOPASSWD: ALL' | sudo tee /etc/sudoers.d/petalinux && sudo chmod 440 /etc/sudoers.d/petalinux"

# 3. Mount /data
ssh petalinux@192.168.0.93 "sudo umount /run/media/mmcblk0p3 2>/dev/null; sudo mkdir -p /data && echo '/dev/mmcblk0p3  /data  ext4  defaults  0  2' | sudo tee -a /etc/fstab && sudo mount /data && df -h /data"
```
