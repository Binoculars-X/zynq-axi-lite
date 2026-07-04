`timescale 1 ns / 1 ps
// axi_regs256.v
// AXI4-Lite loopback register file: 256 x 32-bit general-purpose registers.
// Reg[0] hardwired to PING_CONST (0xA0100001) -- read-only health check.
// Reg[1]-Reg[255]: full read/write loopback.
//
// Write/read state machines copied VERBATIM from proven template:
//   axi_train_regs_slave_lite_v1_0_S00_AXI.v
// Only user logic section replaced (register file instead of transformer bridge).

module axi_regs256_slave_lite_v1_0_S00_AXI #(
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
	reg [1:0]	axi_rresp;
	reg	axi_rvalid;

	// Address decode constants -- verbatim from template
	localparam integer ADDR_LSB = (C_S_AXI_DATA_WIDTH/32) + 1;   // 2 for 32-bit
	localparam integer OPT_MEM_ADDR_BITS = 7;  // 8-bit word index -> 256 registers

	// Ping constant at reg[0] -- hardwired, never writable
	localparam [31:0] PING_CONST = 32'hA0100001;

	// Register file: reg[1]-reg[255] are read/write loopback
	// reg[0] reads as PING_CONST
	reg [31:0] mem [0:255];
	integer byte_index;

	// Combinational read mux output -- verbatim pattern from template
	reg [31:0] reg_data_out;

	// I/O Connections -- verbatim from template
	assign S_AXI_AWREADY = axi_awready;
	assign S_AXI_WREADY  = axi_wready;
	assign S_AXI_BRESP   = axi_bresp;
	assign S_AXI_BVALID  = axi_bvalid;
	assign S_AXI_ARREADY = axi_arready;
	assign S_AXI_RRESP   = axi_rresp;
	assign S_AXI_RVALID  = axi_rvalid;

	// State machine variables -- verbatim from template
	reg [1:0] state_write;
	reg [1:0] state_read;
	// State machine local parameters -- verbatim from template
	localparam Idle = 2'b00, Raddr = 2'b10, Rdata = 2'b11, Waddr = 2'b10, Wdata = 2'b11;

	// ── Write state machine -- VERBATIM from template ────────────────────────
	always @(posedge S_AXI_ACLK)
	  begin
	     if (S_AXI_ARESETN == 1'b0)
	       begin
	         axi_awready <= 0;
	         axi_wready <= 0;
	         axi_bvalid <= 0;
	         axi_bresp <= 0;
	         axi_awaddr <= 0;
	         state_write <= Idle;
	       end
	     else
	       begin
	         case(state_write)
	           Idle:
	             begin
	               if(S_AXI_ARESETN == 1'b1)
	                 begin
	                   axi_awready <= 1'b1;
	                   axi_wready <= 1'b1;
	                   state_write <= Waddr;
	                 end
	               else state_write <= state_write;
	             end
	           Waddr:
	             begin
	               if (S_AXI_AWVALID && S_AXI_AWREADY)
	                  begin
	                    axi_awaddr <= S_AXI_AWADDR;
	                    if(S_AXI_WVALID)
	                      begin
	                        axi_awready <= 1'b1;
	                        state_write <= Waddr;
	                        axi_bvalid <= 1'b1;
	                      end
	                    else
	                      begin
	                        axi_awready <= 1'b0;
	                        state_write <= Wdata;
	                        if (S_AXI_BREADY && axi_bvalid) axi_bvalid <= 1'b0;
	                      end
	                  end
	               else
	                  begin
	                    state_write <= state_write;
	                    if (S_AXI_BREADY && axi_bvalid) axi_bvalid <= 1'b0;
	                   end
	             end
	          Wdata:
	             begin
	               if (S_AXI_WVALID)
	                 begin
	                   state_write <= Waddr;
	                   axi_bvalid <= 1'b1;
	                   axi_awready <= 1'b1;
	                 end
	                else
	                 begin
	                   state_write <= state_write;
	                   if (S_AXI_BREADY && axi_bvalid) axi_bvalid <= 1'b0;
	                 end
	             end
	          endcase
	        end
	      end

	// ── Write register file -- user logic only ───────────────────────────────
	always @(posedge S_AXI_ACLK)
	begin
	  if (S_AXI_ARESETN == 1'b0)
	    begin
	      for (byte_index = 0; byte_index < 256; byte_index = byte_index + 1)
	        mem[byte_index] <= 32'd0;
	    end
	  else begin
	    if (S_AXI_WVALID)
	      begin
	        // Address mux verbatim from template
	        if (S_AXI_WSTRB[0]) mem[(S_AXI_AWVALID) ? S_AXI_AWADDR[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] : axi_awaddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB]][ 7: 0] <= S_AXI_WDATA[ 7: 0];
	        if (S_AXI_WSTRB[1]) mem[(S_AXI_AWVALID) ? S_AXI_AWADDR[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] : axi_awaddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB]][15: 8] <= S_AXI_WDATA[15: 8];
	        if (S_AXI_WSTRB[2]) mem[(S_AXI_AWVALID) ? S_AXI_AWADDR[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] : axi_awaddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB]][23:16] <= S_AXI_WDATA[23:16];
	        if (S_AXI_WSTRB[3]) mem[(S_AXI_AWVALID) ? S_AXI_AWADDR[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] : axi_awaddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB]][31:24] <= S_AXI_WDATA[31:24];
	      end
	  end
	end

	// ── Read state machine -- VERBATIM from template ─────────────────────────
	always @(posedge S_AXI_ACLK)
	  begin
	    if (S_AXI_ARESETN == 1'b0)
	      begin
	       axi_arready <= 1'b0;
	       axi_rvalid <= 1'b0;
	       axi_rresp <= 1'b0;
	       state_read <= Idle;
	      end
	    else
	      begin
	        case(state_read)
	          Idle:
	            begin
	              if (S_AXI_ARESETN == 1'b1)
	                begin
	                  state_read <= Raddr;
	                  axi_arready <= 1'b1;
	                end
	              else state_read <= state_read;
	            end
	          Raddr:
	            begin
	              if (S_AXI_ARVALID && S_AXI_ARREADY)
	                begin
	                  state_read <= Rdata;
	                  axi_araddr <= S_AXI_ARADDR;
	                  axi_rvalid <= 1'b1;
	                  axi_arready <= 1'b0;
	                end
	              else state_read <= state_read;
	            end
	          Rdata:
	            begin
	              if (S_AXI_RVALID && S_AXI_RREADY)
	                begin
	                  axi_rvalid <= 1'b0;
	                  axi_arready <= 1'b1;
	                  state_read <= Raddr;
	                end
	              else state_read <= state_read;
	            end
	         endcase
	        end
	      end

	// ── Read data mux -- combinational, verbatim pattern from template ────────
	assign S_AXI_RDATA = reg_data_out;

	always @(*) begin
	  reg_data_out = 32'hDEADBEEF;
	  case (axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB])
	    8'h00:    reg_data_out = PING_CONST;          // reg[0] hardwired
	    default:  reg_data_out = mem[axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB]];
	  endcase
	end

endmodule
