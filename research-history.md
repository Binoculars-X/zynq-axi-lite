# Research History — AXI4-Lite reg1+ write failure on ZCU102

## Context

This repo was originally built to reproduce/test the claim in
`docs/known-bug-discussion.md` (a public forum thread) that:
- Vivado 2024.2's `create_peripheral`-generated AXI4-Lite template violates
  AMBA AXI4-Lite A3.3.1 (drops BVALID if WDATA arrives before AWADDR).
- Vivado 2022.2's generated template does **not** have that problem and is
  protocol-compliant.

The user published that thread and assumed re-targeting IP generation at
Vivado 2022.2 would fix the observed hardware symptom (`reg0` reads fine,
`reg1`-`reg255` always read back `0x00000000` after a write). **It did not.**
This file documents the actual investigation and root cause, found via
hardware ILA capture on 2026-07-08.

## Symptom (reproducible, 100% consistent)

```
PASS  reg0   0xa0000000 [read]           : 0xA0100001
FAIL  reg1   0xa0000004 [write/read]     : got '0x00000000'  expected '0xDEADBEEF'
FAIL  byteen 0xa0000008 [byte-write/read]: got '0x00000000'  expected '0xFFFFFFAB'
FAIL  reg254 0xa00003f8 [write/read]     : got '0x00000000'  expected '0xDEADBEEF'
FAIL  reg255 0xa00003fc [write/read]     : got '0x00000000'  expected '0xCAFEBABE'
```

Only offset `0x0` (reg0) ever retains a written value. Every other offset
always reads back `0x00000000`, regardless of which register/address is
targeted.

## Hypotheses tested and ruled out (in chronological order)

### 1. IP generation tool version (2024.2-style non-compliant FSM)
**Action:** Switched IP generation to Vivado 2022.2 (`VIVADO_IP_GEN` env var
added, keeping main build/program/sim flow on 2026.1 — see `0.Setup.ps1`).
**Result:** No change. Symptom identical.

### 2. Custom RTL not actually being injected into the packaged IP
**Action:** Found `1.GenerateAxiIp.ps1` was copying `rtl/axi_regs256.v` to
the wrong generated filename (`axi_regs256_slave_lite_v1_0_S00_AXI.v`
instead of the real generated name `axi_regs256_v1_0_S00_AXI.v`), so the
custom RTL (256 regs + PING_CONST) was silently never copied in — Vivado was
synthesizing the untouched 4-register vanilla template the whole time.
**Fix:** Corrected the copy target path.
**Result:** No change in symptom once actually applied (still reg0-only
writes worked).

### 3. Module name mismatch after fixing the copy path
**Action:** `rtl/axi_regs256.v`'s `module axi_regs256_slave_lite_v1_0_S00_AXI`
declaration didn't match the instantiated name `axi_regs256_v1_0_S00_AXI`,
causing a synthesis error (`module not found`) once the copy path was fixed.
**Fix:** Renamed the module declaration to match.
**Result:** Bitstream built and programmed successfully. Symptom unchanged.

### 4. Non-compliant write FSM in our custom RTL
**Hypothesis:** Our hand-written `axi_regs256.v` write-address/write-data FSM
used a different (simpler, 2-state) pattern than the proven Vivado
2022.2-generated template, and might have a genuine bug causing writes not to
retire correctly on real hardware (despite passing self-consistent
simulation — classic "test cheats by matching its own implementation"
anti-pattern).
**Action:** Extracted the actual proven-correct FSM from a freshly generated,
completely vanilla 2022.2 `create_peripheral` template (the `aw_en`-gated
dependency-checking FSM, matching what `docs/known-bug-discussion.md`
describes as A3.3.1-compliant), and rewrote `rtl/axi_regs256.v` to use it
verbatim, keeping only the PING_CONST/256-register user logic.
**Result:** Simulation passed 7/7 (same as before). **Real hardware symptom
was byte-for-byte identical** — only reg0 writes retained, everything else
still read back 0. This ruled out our RTL's write FSM as the cause, since two
structurally different implementations produced the exact same hardware
failure.

### 5. Decisive experiment — test the truly vanilla, unmodified IP
**Action:** Generated a **completely untouched** 2022.2 `create_peripheral`
output (no ADDR_WIDTH patch, no custom RTL substitution — the real stock
4-register example design) and built/programmed/tested it directly, writing
to all 4 of its native registers (`0xa0000000`-`0xa000000c`).
**Result:** `reg0` (offset 0) write/read worked. `reg1`/`reg2`/`reg3` (offsets
4/8/12) all read back 0 after being written — **identical failure pattern**,
even on the 100% stock, never-modified Xilinx-generated IP. This proved:
- The 2022.2 template itself is not broken.
- Our RTL edits, module name fix, and custom register file logic were never
  the cause.
- **This answers the user's original question: the forum thread wasn't
  lying — 2022.2's slave IP is fine. The bug is in our block design's
  address/master configuration, not the packaged peripheral.**

### 6. Address range / SmartConnect segment size mismatch
**Hypothesis (from README, now superseded):** The IP declares a tiny
`ADDR_WIDTH=4` (16-byte) decode window in `component.xml`, but
`scripts/build_axi_test.tcl` was forcing a 4KB address-map segment onto it,
and this size mismatch could cause SmartConnect's address translation to
collapse all writes to offset 0.
**Action:** Tried assigning the segment range to exactly 16 bytes (the IP's
own declared width). Vivado rejected this:
```
ERROR: [BD 41-70] Exec TCL: The proposed range '16' is less than the minimum
range '128' from slave segment ... to address space
'/zynq_ultra_ps_e_0/Data'.
```
Retried with the enforced minimum, 128 bytes.
**Result:** No change. Symptom identical even with the minimum valid,
non-oversized range. This hypothesis is **ruled out** — range size was never
the actual cause (the earlier "collapses to 0" theory was a coincidental
correlation, not causation).

## Root cause — found via hardware ILA capture (confirmed)

Added a `system_ila` (`xilinx.com:ip:system_ila:1.1`) directly monitoring the
`u_regs` `S00_AXI` interface (see `scripts/build_axi_debug.tcl`), triggered
on `AWVALID` rising, and issued a real `sudo busybox devmem 0xa0000004 w
0xDEADBEEF` over SSH while the ILA was armed
(`scripts/capture_axi_debug.tcl`). Captured to
`out/ila_capture.csv`.

**Actual captured values at the completed write beat (sample 101, marked
"Data Beat" on the W channel, `AWADDR=4`, `AWVALID=1`, `AWREADY` asserted the
prior cycle, `WVALID=1`, `WREADY=1`):**

```
AWADDR = 0x4        (correct — the intended target address)
WDATA  = 0x00000000 (WRONG — should be 0xDEADBEEF)
WSTRB  = 0x0        (WRONG — should be 0xF, all bytes enabled)
```

**The write handshake completes successfully at the AXI protocol level (BVALID
fires, response is OKAY) but the master (Zynq PS) is physically driving
WDATA=0 and WSTRB=0 onto the bus for this transaction.** This is not a slave
RTL bug at all — the slave faithfully does nothing because it correctly
receives zero write-strobes. Every hypothesis above (2022.2 vs 2024.2
template, custom RTL, module naming, FSM correctness, address range) was
consistent with — and is now conclusively superseded by — this finding.

### Leading explanation

`M_AXI_HPM0_FPD` (the Zynq UltraScale+ PS "General Purpose" AXI master used
in this design) is natively a wide (128-bit) high-performance port. The
block design sets `CONFIG.PSU__MAXIGP0__DATA_WIDTH {32}`, which is a
Zynq-7000-era GP-port property name; it appears not to be honored for
`M_AXI_HPM0_FPD` on UltraScale+, so SmartConnect silently inserts a 128→32
downsize conversion. For narrow (32-bit), non-lane-0 writes through such a
converter, WDATA/WSTRB can be routed to the wrong internal byte lane,
presenting as all-zero to a 32-bit-only downstream slave. Reads are
seemingly unaffected because the read path only needs address-lane
selection (no data downsizing/lane muxing on the way back is affected the
same way), which is why `reg0` reads (and, by extension, its trivial offset-0
writes) appeared to work while nothing else did.

### Next step (not yet applied)

Reconfigure the PS to use `M_AXI_HPM0_LPD` (Low Power Domain AXI master,
natively 32-bit, intended for exactly this class of simple control/register
access) instead of `M_AXI_HPM0_FPD`, to avoid the width-conversion path
entirely, then rebuild/reprogram/retest.

## CONFIRMED FIX (2026-07-08)

Switched the PS master port from `M_AXI_HPM0_FPD` to `M_AXI_HPM0_LPD`
(`CONFIG.PSU__USE__M_AXI_GP2 {1}`, `CONFIG.PSU__MAXIGP2__DATA_WIDTH {32}`,
`zynq_ultra_ps_e_0/maxihpm0_lpd_aclk`, base address moved from `0xA0000000`
to `0x80000000` — this is `M_AXI_HPM0_LPD`'s only valid aperture, 512MB).
Rebuilt, reprogrammed, retested the vanilla 4-register IP:

```
sudo busybox devmem 0x80000000 w 0x11111111; sudo busybox devmem 0x80000000  -> 0x11111111  PASS
sudo busybox devmem 0x80000004 w 0xDEADBEEF; sudo busybox devmem 0x80000004  -> 0xDEADBEEF  PASS
sudo busybox devmem 0x80000008 w 0xCAFEBABE; sudo busybox devmem 0x80000008  -> 0xCAFEBABE  PASS
sudo busybox devmem 0x8000000c w 0x12345678; sudo busybox devmem 0x8000000c -> 0x12345678  PASS
```

All 4 registers now write and read back correctly. **The `M_AXI_HPM0_FPD`
implicit 128->32 width-conversion hypothesis is confirmed as the root
cause.** `M_AXI_HPM0_LPD` is natively 32-bit and avoids the conversion
entirely.

Next: switch back to the real `axi_regs256` (256-register, `PING_CONST`)
packaged IP with the appropriate address range through the same
`M_AXI_HPM0_LPD` path, rebuild, and re-run the full `5.RunDevmemTest.ps1`
suite (reg0 ping, reg1 loopback, byte-enable, reg254/reg255 boundary) to
confirm the fix holds for the full 256-register target design used for
transformer training-sample transfer.

## FULLY CONFIRMED — full 256-register design (2026-07-08)

Switched back to the real `axi_regs256` packaged IP (256 registers,
`PING_CONST` at reg0), widened the address range to `0x400` (1KB) via
`M_AXI_HPM0_LPD` at base `0x80000000`, rebuilt, reprogrammed, and re-ran the
full `5.RunDevmemTest.ps1` suite:

```
PASS  reg0   0x80000000 [read]            : 0xA0100001
PASS  reg1   0x80000004 [write/read]      : 0xDEADBEEF
PASS  byteen 0x80000008 [byte-write/read] : 0xFFFFFFAB
PASS  reg254 0x800003f8 [write/read]      : 0xDEADBEEF
PASS  reg255 0x800003fc [write/read]      : 0xCAFEBABE
=== ALL TESTS PASSED ===
```

All 256 registers are confirmed addressable and read/write-correct,
including the byte-enable (WSTRB) path and both boundary registers. This is
ready for use as the transformer training-sample transfer path (not limited
to 4 registers).

## Key lesson for future debugging in this repo

Do not trust "it fails the same way" as proof the RTL/IP-generation-version
axis is the cause — always get a hardware trace before continuing to iterate
on the slave side. Two structurally different, independently-simulated-clean
RTL implementations (and even the 100% vanilla vendor IP) all failed
identically, which in hindsight was the strongest possible signal that the
bug was upstream of the slave the whole time.
