`timescale 1 ns / 1 ps
// axi_regs256.sv
// Self-contained, hardware-verified AXI4-Lite loopback register file:
// 256 x 32-bit general-purpose registers, single file, zero dependencies.
//
// Reg[0]        = hardwired PING_CONST (0xA0100001), read-only health check.
// Reg[1]-[255]  = full read/write loopback (byte-enable and boundary
//                 registers hardware-verified on ZCU102, see project README
//                 and research-history.md in the parent zynq-axi-lite repo).
//
// Write/read handshake FSM is the AMBA AXI4-Lite A3.3.1 compliant
// aw_en-gated dependency-checking design (Vivado 2022.2 create_peripheral
// template). Only user logic (register file + PING_CONST mux) differs
// from the stock template.
//
// This file is exported standalone so it can be dropped into any Vivado
// project (RTL reference OR IP-Packager flow) without needing the rest of
// the zynq-axi-lite build scripts (steps 0-5).
//
// See README.md in this folder for import instructions.

module axi_regs256_v1_0_S00_AXI #(
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 32
)(
    // Clock
    (* X_INTERFACE_INFO      = "xilinx.com:signal:clock:1.0 S_AXI_ACLK CLK" *)
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME S_AXI_ACLK, ASSOCIATED_BUSIF S_AXI, ASSOCIATED_RESET S_AXI_ARESETN" *)
    input  wire                                    S_AXI_ACLK,
    // Reset
    (* X_INTERFACE_INFO      = "xilinx.com:signal:reset:1.0 S_AXI_ARESETN RST" *)
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME S_AXI_ARESETN, POLARITY ACTIVE_LOW" *)
    input  wire                                    S_AXI_ARESETN,
    // AXI4-Lite slave
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME S_AXI, DATA_WIDTH 32, PROTOCOL AXI4LITE, ADDR_WIDTH 32, NUM_READ_OUTSTANDING 1, NUM_WRITE_OUTSTANDING 1, READ_WRITE_MODE READ_WRITE" *)
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWADDR"  *) input  wire [C_S_AXI_ADDR_WIDTH-1:0]    S_AXI_AWADDR,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWPROT"  *) input  wire [2:0]                        S_AXI_AWPROT,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWVALID" *) input  wire                              S_AXI_AWVALID,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWREADY" *) output wire                              S_AXI_AWREADY,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WDATA"   *) input  wire [C_S_AXI_DATA_WIDTH-1:0]    S_AXI_WDATA,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WSTRB"   *) input  wire [(C_S_AXI_DATA_WIDTH/8)-1:0] S_AXI_WSTRB,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WVALID"  *) input  wire                              S_AXI_WVALID,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WREADY"  *) output wire                              S_AXI_WREADY,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI BRESP"   *) output wire [1:0]                        S_AXI_BRESP,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI BVALID"  *) output wire                              S_AXI_BVALID,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI BREADY"  *) input  wire                              S_AXI_BREADY,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARADDR"  *) input  wire [C_S_AXI_ADDR_WIDTH-1:0]    S_AXI_ARADDR,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARPROT"  *) input  wire [2:0]                        S_AXI_ARPROT,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARVALID" *) input  wire                              S_AXI_ARVALID,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARREADY" *) output wire                              S_AXI_ARREADY,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RDATA"   *) output wire [C_S_AXI_DATA_WIDTH-1:0]    S_AXI_RDATA,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RRESP"   *) output wire [1:0]                        S_AXI_RRESP,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RVALID"  *) output wire                              S_AXI_RVALID,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RREADY"  *) input  wire                              S_AXI_RREADY
);

	// AXI4LITE signals -- verbatim from template
	reg [C_S_AXI_ADDR_WIDTH-1:0]	axi_awaddr;
	reg	axi_awready;
	reg	axi_wready;
	reg [1:0]	axi_bresp;
	reg	axi_bvalid;
	reg [C_S_AXI_ADDR_WIDTH-1:0]	axi_araddr;
	reg	axi_arready;
	reg [C_S_AXI_DATA_WIDTH-1:0]	axi_rdata;
	reg [1:0]	axi_rresp;
	reg	axi_rvalid;
	reg	aw_en;

	// Address decode constants -- verbatim from template
	localparam integer ADDR_LSB = (C_S_AXI_DATA_WIDTH/32) + 1;   // 2 for 32-bit
	localparam integer OPT_MEM_ADDR_BITS = 7;  // 8-bit word index -> 256 registers

	// Ping constant at reg[0] -- hardwired, never writable
	localparam [31:0] PING_CONST = 32'hA0100001;

	// Register file: reg[1]-reg[255] are read/write loopback
	// reg[0] reads as PING_CONST
	reg [31:0] mem [0:255];
	integer byte_index;

	wire slv_reg_wren;
	wire slv_reg_rden;
	reg [31:0] reg_data_out;

	// I/O Connections -- verbatim from template
	assign S_AXI_AWREADY = axi_awready;
	assign S_AXI_WREADY  = axi_wready;
	assign S_AXI_BRESP   = axi_bresp;
	assign S_AXI_BVALID  = axi_bvalid;
	assign S_AXI_ARREADY = axi_arready;
	assign S_AXI_RDATA   = axi_rdata;
	assign S_AXI_RRESP   = axi_rresp;
	assign S_AXI_RVALID  = axi_rvalid;

	// ── axi_awready generation -- VERBATIM from template ──────────────────────
	// Asserted for one cycle when both AWVALID and WVALID are asserted
	// (A3.3.1 dependency: slave waits for both before accepting the address).
	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_awready <= 1'b0;
	      aw_en <= 1'b1;
	    end
	  else
	    begin
	      if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID && aw_en)
	        begin
	          axi_awready <= 1'b1;
	          aw_en <= 1'b0;
	        end
	        else if (S_AXI_BREADY && axi_bvalid)
	            begin
	              aw_en <= 1'b1;
	              axi_awready <= 1'b0;
	            end
	      else
	        begin
	          axi_awready <= 1'b0;
	        end
	    end
	end

	// ── axi_awaddr latching -- VERBATIM from template ─────────────────────────
	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_awaddr <= 0;
	    end
	  else
	    begin
	      if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID && aw_en)
	        begin
	          axi_awaddr <= S_AXI_AWADDR;
	        end
	    end
	end

	// ── axi_wready generation -- VERBATIM from template ───────────────────────
	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_wready <= 1'b0;
	    end
	  else
	    begin
	      if (~axi_wready && S_AXI_WVALID && S_AXI_AWVALID && aw_en )
	        begin
	          axi_wready <= 1'b1;
	        end
	      else
	        begin
	          axi_wready <= 1'b0;
	        end
	    end
	end

	// ── Write register file -- user logic, gated by proven handshake ─────────
	// slv_reg_wren asserted only on the one cycle both AW and W handshakes
	// complete -- VERBATIM gating condition from template.
	assign slv_reg_wren = axi_wready && S_AXI_WVALID && axi_awready && S_AXI_AWVALID;

	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      for (byte_index = 0; byte_index < 256; byte_index = byte_index + 1)
	        mem[byte_index] <= 32'd0;
	    end
	  else begin
	    if (slv_reg_wren)
	      begin
	        if (S_AXI_WSTRB[0]) mem[axi_awaddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB]][ 7: 0] <= S_AXI_WDATA[ 7: 0];
	        if (S_AXI_WSTRB[1]) mem[axi_awaddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB]][15: 8] <= S_AXI_WDATA[15: 8];
	        if (S_AXI_WSTRB[2]) mem[axi_awaddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB]][23:16] <= S_AXI_WDATA[23:16];
	        if (S_AXI_WSTRB[3]) mem[axi_awaddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB]][31:24] <= S_AXI_WDATA[31:24];
	      end
	  end
	end

	// ── Write response logic -- VERBATIM from template ────────────────────────
	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_bvalid  <= 0;
	      axi_bresp   <= 2'b0;
	    end
	  else
	    begin
	      if (axi_awready && S_AXI_AWVALID && ~axi_bvalid && axi_wready && S_AXI_WVALID)
	        begin
	          axi_bvalid <= 1'b1;
	          axi_bresp  <= 2'b0; // 'OKAY' response
	        end
	      else
	        begin
	          if (S_AXI_BREADY && axi_bvalid)
	            begin
	              axi_bvalid <= 1'b0;
	            end
	        end
	    end
	end

	// ── axi_arready / axi_araddr -- VERBATIM from template ────────────────────
	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_arready <= 1'b0;
	      axi_araddr  <= 32'b0;
	    end
	  else
	    begin
	      if (~axi_arready && S_AXI_ARVALID)
	        begin
	          axi_arready <= 1'b1;
	          axi_araddr  <= S_AXI_ARADDR;
	        end
	      else
	        begin
	          axi_arready <= 1'b0;
	        end
	    end
	end

	// ── axi_rvalid -- VERBATIM from template ──────────────────────────────────
	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_rvalid <= 0;
	      axi_rresp  <= 0;
	    end
	  else
	    begin
	      if (axi_arready && S_AXI_ARVALID && ~axi_rvalid)
	        begin
	          axi_rvalid <= 1'b1;
	          axi_rresp  <= 2'b0; // 'OKAY' response
	        end
	      else if (axi_rvalid && S_AXI_RREADY)
	        begin
	          axi_rvalid <= 1'b0;
	        end
	    end
	end

	// ── Read data mux -- user logic: reg[0] hardwired to PING_CONST ──────────
	assign slv_reg_rden = axi_arready & S_AXI_ARVALID & ~axi_rvalid;
	always @(*)
	begin
	  case ( axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] )
	    8'h00:   reg_data_out <= PING_CONST;   // reg[0] hardwired
	    default: reg_data_out <= mem[axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB]];
	  endcase
	end

	// ── Output read data register -- VERBATIM from template ──────────────────
	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_rdata  <= 0;
	    end
	  else
	    begin
	      if (slv_reg_rden)
	        begin
	          axi_rdata <= reg_data_out;
	        end
	    end
	end

endmodule
