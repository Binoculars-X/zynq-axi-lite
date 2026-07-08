# ip-export — standalone `axi_regs256` AXI4-Lite slave

A single, hardware-verified, dependency-free artifact for the AXI4-Lite
loopback register file proven end-to-end on ZCU102 (see main
[README.md](../README.md) and [research-history.md](../research-history.md)
in the parent `zynq-axi-lite` project). Use this folder to drop the slave
into **any other Vivado/PetaLinux project** without running the full
0–5 build pipeline.

## Contents

| File | Purpose |
|------|---------|
| `axi_regs256.sv` | The IP itself. One file, no includes, no external deps. |
| `package_ip.tcl` | Optional: packages the `.sv` as a reusable Vivado IP-Integrator catalog IP. |

## What it is

- Module: `axi_regs256_v1_0_S00_AXI`
- AXI4-Lite slave, 32-bit data/address, 256 x 32-bit registers (1 KB address range)
- `reg[0]` = hardwired ping constant `0xA0100001` (read-only)
- `reg[1]`–`reg[255]` = full read/write loopback, byte-enable (`WSTRB`) supported
- FSM is the AMBA AXI4-Lite A3.3.1-compliant `aw_en`-gated design (Vivado
  `create_peripheral` template) — hardware-verified, not just simulation-passing

## Import option 1 — direct RTL instantiation (simplest)

Copy `axi_regs256.sv` into your project's sources and instantiate directly,
either in your own top-level RTL or wired manually in a Block Design as an
**RTL Module** (Block Design → Add Module → browse to the file).

```verilog
axi_regs256_v1_0_S00_AXI #(
    .C_S_AXI_DATA_WIDTH(32),
    .C_S_AXI_ADDR_WIDTH(32)
) u_axi_regs256 (
    .S_AXI_ACLK    (pl_clk0),
    .S_AXI_ARESETN (peripheral_aresetn),
    .S_AXI_AWADDR  (...),
    .S_AXI_AWPROT  (...),
    .S_AXI_AWVALID (...),
    .S_AXI_AWREADY (...),
    .S_AXI_WDATA   (...),
    .S_AXI_WSTRB   (...),
    .S_AXI_WVALID  (...),
    .S_AXI_WREADY  (...),
    .S_AXI_BRESP   (...),
    .S_AXI_BVALID  (...),
    .S_AXI_BREADY  (...),
    .S_AXI_ARADDR  (...),
    .S_AXI_ARPROT  (...),
    .S_AXI_ARVALID (...),
    .S_AXI_ARREADY (...),
    .S_AXI_RDATA   (...),
    .S_AXI_RRESP   (...),
    .S_AXI_RVALID  (...),
    .S_AXI_RREADY  (...)
);
```

The module carries `X_INTERFACE_INFO`/`X_INTERFACE_PARAMETER` attributes, so
even as a plain RTL Module in a Block Design, Vivado auto-detects the
`S_AXI` AXI4-Lite bus interface and clock/reset associations for
auto-connection.

## Import option 2 — package as a catalog IP

Run the Tcl wrapper to package it as a normal Vivado IP you can add to an
IP repository and reuse across projects:

```powershell
cd C:\repos\_Neuro\zynq-axi-lite\ip-export
& C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat -mode batch -source package_ip.tcl -tclargs C:\path\to\my_ip_repo
```

Then in your target project:
1. **Tools → Settings → IP → Repository → Add Repository** → point at `C:\path\to\my_ip_repo`
2. Refresh the IP catalog
3. In your Block Design, **Add IP** → search "AXI Regs256" → instantiate
4. Vivado auto-connects the AXI4-Lite interface and clock/reset via Designer Assistance

## Block Design wiring notes (from the hardware-verified reference project)

- **Use `M_AXI_HPM0_LPD`, not `M_AXI_HPM0_FPD`**, from the Zynq UltraScale+ PS.
  `M_AXI_HPM0_FPD` is a 128-bit port; SmartConnect silently inserts a
  128→32 downsize converter that corrupts `WDATA`/`WSTRB` on narrow AXI4-Lite
  writes. `M_AXI_HPM0_LPD` is natively 32-bit and avoids this entirely.
- Base address / valid aperture for `M_AXI_HPM0_LPD` is fixed at `0x80000000` (512 MB).
  Assign the IP anywhere in that range; 1 KB is sufficient (`C_S_AXI_ADDR_WIDTH=10`
  effective decode, though the port itself is 32-bit wide).
- Do **not** insert `axi_protocol_converter` between SmartConnect and this
  slave — it causes permanent AXI write hangs (RCU stall) on ZCU102.
  SmartConnect converts AXI4 → AXI4-Lite internally; connect it directly.
- Register map:

  | Address offset | Register | Access |
  |---|---|---|
  | `0x000` | `reg[0]` — ping constant `0xA0100001` | read-only |
  | `0x004`–`0x3FC` | `reg[1]`–`reg[255]` | read/write |

## Verifying the import

From Linux userspace on your target board (same pattern as the parent
project's `5.RunDevmemTest.ps1`):

```sh
busybox devmem 0x80000000 32          # expect 0xA0100001
busybox devmem 0x80000004 32 0xDEADBEEF
busybox devmem 0x80000004 32          # expect 0xDEADBEEF
```
