# zynq-axi-lite
End-to-end Zynq/ZCU102 ARM Linux to PL AXI4-Lite template.

**Imported**
# axi-test

Minimal AXI4-Lite loopback test for ZCU102.  
Proves the ARM PS → SmartConnect → axi_protocol_converter → AXI4-Lite slave path works end-to-end.

## Build (JETPC)

```powershell
cd C:\repos\_Neuro\axi-test\scripts
.\build_axi_test.ps1
```

Output: `C:/axtest/out/axi_test.bit`

## Program (JETPC, board connected via JTAG)

```powershell
cd C:\repos\_Neuro\axi-test\scripts
.\program_axi_test.ps1
```

## Test (ZCU102 Linux over SSH)

```bash
ssh petalinux@192.168.0.93
```

### 1. Confirm the address range is visible to Linux

```bash
cat /proc/iomem | grep -i a0000
```

Expected: a line covering `a0000000`. If missing, `/dev/mem` access may be blocked — see Troubleshooting below.

### 2. Ping constant (reg 0 — hardwired, never writable)

```bash
sudo busybox devmem 0xa0000000
```

Expected output:
```
0xA0100001
```

This confirms the entire path is alive: PS → SmartConnect → protocol_converter → slave → response.

### 3. Write / read loopback (reg 1)

```bash
sudo busybox devmem 0xa0000004 w 0x12345678
sudo busybox devmem 0xa0000004
# expect: 0x12345678
```

### 4. Byte-enable test (partial write)

```bash
sudo busybox devmem 0xa0000008 w 0xFFFFFFFF
sudo busybox devmem 0xa0000008 b 0xAB
sudo busybox devmem 0xa0000008
# expect: 0xFFFFFFAB
```

### 5. Boundary registers

```bash
sudo busybox devmem 0xa00003f8 w 0xDEADBEEF
sudo busybox devmem 0xa00003fc w 0xCAFEBABE
sudo busybox devmem 0xa00003f8
# expect: 0xDEADBEEF
sudo busybox devmem 0xa00003fc
# expect: 0xCAFEBABE
```

## Pass / Fail criteria

| Test | Expected | Fail means |
|------|----------|------------|
| Ping constant | `0xA0100001` | AXI path dead — clock/reset or addressing wrong |
| Write loopback | value written | Slave write handshake broken (BVALID issue) |
| Read loopback | value written | Slave read mux broken |
| Byte enable | partial update | WSTRB not reaching slave correctly |
| Boundary | values written | Address decode wraps or truncates |

## Troubleshooting

**`devmem2` hangs** — BVALID never asserted. The write state machine stalls waiting for BREADY before it can accept a new AWVALID. Check that Linux is sending BREADY (it should — `devmem2` is a single transaction).

**`devmem2` returns 0 for everything** — Address decode is off. Verify `/proc/iomem` shows the slave at `a0000000`.

**`/dev/mem: Operation not permitted`** — Kernel has `CONFIG_STRICT_DEVMEM=y`. Run:
```bash
devmem2 0xa0000000   # may need sudo
# or load the uio driver and access via /dev/uio0
```

**`devmem2` not found** — Use `sudo busybox devmem` instead (available on this PetaLinux image):
```bash
sudo busybox devmem 0xa0000000
```

## What this proves

If all tests pass, the wiring pattern in `scripts/build_axi_test.tcl` is correct:
- `axi_protocol_converter` (SI=AXI4, MI=AXI4LITE, TRANSLATION_MODE=2) correctly strips bursts
- Module reference with `X_INTERFACE_PARAMETER PROTOCOL AXI4LITE` is sufficient for Vivado IPI
- The same pattern can be applied to `axi_train_regs` in the main transformer build
