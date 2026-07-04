`timescale 1ns / 1ps
// tb_axi_regs256.v
// Minimal AXI4-Lite master testbench for axi_regs256.
// Tests: write reg[1], read back, check BVALID handshake cycle by cycle.

module tb_axi_regs256;

    // Clock and reset
    reg clk = 0;
    reg rstn = 0;
    always #5 clk = ~clk; // 100 MHz

    // AXI4-Lite signals
    reg  [31:0] awaddr;
    reg         awvalid;
    wire        awready;
    reg  [31:0] wdata;
    reg  [3:0]  wstrb;
    reg         wvalid;
    wire        wready;
    wire [1:0]  bresp;
    wire        bvalid;
    reg         bready;
    reg  [31:0] araddr;
    reg         arvalid;
    wire        arready;
    wire [31:0] rdata;
    wire [1:0]  rresp;
    wire        rvalid;
    reg         rready;

    // DUT
    axi_regs256 #(
        .C_S_AXI_DATA_WIDTH(32),
        .C_S_AXI_ADDR_WIDTH(32)
    ) dut (
        .S_AXI_ACLK    (clk),
        .S_AXI_ARESETN (rstn),
        .S_AXI_AWADDR  (awaddr),
        .S_AXI_AWPROT  (3'b0),
        .S_AXI_AWVALID (awvalid),
        .S_AXI_AWREADY (awready),
        .S_AXI_WDATA   (wdata),
        .S_AXI_WSTRB   (wstrb),
        .S_AXI_WVALID  (wvalid),
        .S_AXI_WREADY  (wready),
        .S_AXI_BRESP   (bresp),
        .S_AXI_BVALID  (bvalid),
        .S_AXI_BREADY  (bready),
        .S_AXI_ARADDR  (araddr),
        .S_AXI_ARPROT  (3'b0),
        .S_AXI_ARVALID (arvalid),
        .S_AXI_ARREADY (arready),
        .S_AXI_RDATA   (rdata),
        .S_AXI_RRESP   (rresp),
        .S_AXI_RVALID  (rvalid),
        .S_AXI_RREADY  (rready)
    );

    // VCD dump
    initial begin
        $dumpfile("tb_axi_regs256.vcd");
        $dumpvars(0, tb_axi_regs256);
    end

    // AXI idle defaults
    initial begin
        awaddr  = 0; awvalid = 0;
        wdata   = 0; wstrb   = 4'hF; wvalid = 0;
        bready  = 1; // always ready to accept response
        araddr  = 0; arvalid = 0;
        rready  = 1; // always ready to accept read data
    end

    // Task: AXI4-Lite write (address and data presented simultaneously)
    task axi_write;
        input [31:0] addr;
        input [31:0] data;
        integer timeout;
        begin
            @(posedge clk); #1;
            awaddr  = addr;
            awvalid = 1;
            wdata   = data;
            wstrb   = 4'hF;
            wvalid  = 1;

            // Wait for AWREADY and WREADY
            timeout = 0;
            while (!(awready && wready)) begin
                @(posedge clk); #1;
                timeout = timeout + 1;
                if (timeout > 100) begin
                    $display("TIMEOUT: waiting for AWREADY/WREADY at addr=0x%08X", addr);
                    $finish;
                end
            end
            @(posedge clk); #1;
            awvalid = 0;
            wvalid  = 0;

            // Wait for BVALID
            timeout = 0;
            while (!bvalid) begin
                @(posedge clk); #1;
                timeout = timeout + 1;
                if (timeout > 100) begin
                    $display("TIMEOUT: waiting for BVALID after write to addr=0x%08X", addr);
                    $finish;
                end
            end
            $display("WRITE OK: addr=0x%08X data=0x%08X BRESP=%0b", addr, data, bresp);
            @(posedge clk); #1;
        end
    endtask

    // Task: AXI4-Lite write with AW one cycle BEFORE W (models protocol converter output)
    task axi_write_aw_first;
        input [31:0] addr;
        input [31:0] data;
        integer timeout;
        begin
            // Cycle 1: send AW only
            @(posedge clk); #1;
            awaddr  = addr;
            awvalid = 1;
            wvalid  = 0;

            timeout = 0;
            while (!awready) begin
                @(posedge clk); #1;
                timeout = timeout + 1;
                if (timeout > 100) begin $display("TIMEOUT: AWREADY at addr=0x%08X", addr); $finish; end
            end
            @(posedge clk); #1;
            awvalid = 0;

            // Cycle 2: send W only (AW already gone)
            wdata  = data;
            wstrb  = 4'hF;
            wvalid = 1;

            timeout = 0;
            while (!wready) begin
                @(posedge clk); #1;
                timeout = timeout + 1;
                if (timeout > 100) begin $display("TIMEOUT: WREADY at addr=0x%08X", addr); $finish; end
            end
            @(posedge clk); #1;
            wvalid = 0;

            // Wait for BVALID
            timeout = 0;
            while (!bvalid) begin
                @(posedge clk); #1;
                timeout = timeout + 1;
                if (timeout > 100) begin
                    $display("TIMEOUT: BVALID after AW-first write to addr=0x%08X", addr);
                    $finish;
                end
            end
            $display("WRITE_AW_FIRST OK: addr=0x%08X data=0x%08X BRESP=%0b", addr, data, bresp);
            @(posedge clk); #1;
        end
    endtask

    // Task: AXI4-Lite read
    task axi_read;
        input  [31:0] addr;
        output [31:0] result;
        integer timeout;
        begin
            @(posedge clk); #1;
            araddr  = addr;
            arvalid = 1;

            timeout = 0;
            while (!arready) begin
                @(posedge clk); #1;
                timeout = timeout + 1;
                if (timeout > 100) begin
                    $display("TIMEOUT: waiting for ARREADY at addr=0x%08X", addr);
                    $finish;
                end
            end
            @(posedge clk); #1;
            arvalid = 0;

            timeout = 0;
            while (!rvalid) begin
                @(posedge clk); #1;
                timeout = timeout + 1;
                if (timeout > 100) begin
                    $display("TIMEOUT: waiting for RVALID at addr=0x%08X", addr);
                    $finish;
                end
            end
            result = rdata;
            $display("READ:  addr=0x%08X data=0x%08X RRESP=%0b", addr, rdata, rresp);
            @(posedge clk); #1;
        end
    endtask

    // Main test sequence
    reg [31:0] rd;
    integer pass = 0;
    integer fail = 0;

    initial begin
        // Reset
        rstn = 0;
        repeat(10) @(posedge clk);
        rstn = 1;
        repeat(5) @(posedge clk);

        $display("--- Test 1: Ping constant (reg[0] = 0xA0100001) ---");
        axi_read(32'h00000000, rd);
        if (rd === 32'hA0100001) begin $display("PASS"); pass = pass + 1; end
        else begin $display("FAIL: expected 0xA0100001 got 0x%08X", rd); fail = fail + 1; end

        $display("--- Test 2: Write/read loopback reg[1] ---");
        axi_write(32'h00000004, 32'h12345678);
        axi_read (32'h00000004, rd);
        if (rd === 32'h12345678) begin $display("PASS"); pass = pass + 1; end
        else begin $display("FAIL: expected 0x12345678 got 0x%08X", rd); fail = fail + 1; end

        $display("--- Test 3: Write/read loopback reg[2] ---");
        axi_write(32'h00000008, 32'hDEADBEEF);
        axi_read (32'h00000008, rd);
        if (rd === 32'hDEADBEEF) begin $display("PASS"); pass = pass + 1; end
        else begin $display("FAIL: expected 0xDEADBEEF got 0x%08X", rd); fail = fail + 1; end

        $display("--- Test 4: Boundary reg[255] ---");
        axi_write(32'h000003FC, 32'hCAFEBABE);
        axi_read (32'h000003FC, rd);
        if (rd === 32'hCAFEBABE) begin $display("PASS"); pass = pass + 1; end
        else begin $display("FAIL: expected 0xCAFEBABE got 0x%08X", rd); fail = fail + 1; end

        $display("--- Test 5: Write to reg[0] must NOT overwrite PING_CONST ---");
        axi_write(32'h00000000, 32'hFFFFFFFF);
        axi_read (32'h00000000, rd);
        if (rd === 32'hA0100001) begin $display("PASS"); pass = pass + 1; end
        else begin $display("FAIL: reg[0] was overwritten! got 0x%08X", rd); fail = fail + 1; end

        $display("--- Test 6: AW-first write reg[3] (models protocol converter) ---");
        axi_write_aw_first(32'h0000000C, 32'hABCD1234);
        axi_read(32'h0000000C, rd);
        if (rd === 32'hABCD1234) begin $display("PASS"); pass = pass + 1; end
        else begin $display("FAIL: expected 0xABCD1234 got 0x%08X", rd); fail = fail + 1; end

        $display("--- Test 7: AW-first write reg[255] boundary ---");
        axi_write_aw_first(32'h000003FC, 32'h11223344);
        axi_read(32'h000003FC, rd);
        if (rd === 32'h11223344) begin $display("PASS"); pass = pass + 1; end
        else begin $display("FAIL: expected 0x11223344 got 0x%08X", rd); fail = fail + 1; end

        $display("=== Results: %0d passed, %0d failed ===", pass, fail);
        repeat(5) @(posedge clk);
        $finish;
    end

    // Watchdog
    initial begin
        #100000;
        $display("WATCHDOG: simulation exceeded 100us");
        $finish;
    end

endmodule
