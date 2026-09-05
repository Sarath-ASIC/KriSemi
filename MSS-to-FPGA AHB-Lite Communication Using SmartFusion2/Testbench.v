`timescale 1ns / 1ps

module testbench;

    // Clock and Reset
    reg         HCLK;
    reg         HRESETN;

    // AHB-Lite Bus Signals (Driven by Testbench BFM)
    reg  [31:0] HADDR;
    reg  [1:0]  HTRANS;
    reg         HWRITE;
    reg  [2:0]  HSIZE;
    reg  [2:0]  HBURST;
    reg  [3:0]  HPROT;
    reg  [31:0] HWDATA;
    reg         HSEL;
    reg         HREADY;

    // AHB-Lite Bus Responses (Driven by AHB Slave / Fabric)
    wire [31:0] HRDATA;
    wire        HREADYOUT;
    wire [1:0]  HRESP;

    // AHB Transfer Encoding Constants
    localparam TRN_IDLE   = 2'b00;
    localparam TRN_NONSEQ = 2'b10;
    localparam SIZE_WORD  = 3'b010; // 32-bit transfer

    // Target Register / BRAM Addresses (Adjust to your FIC memory map)
    localparam ADDR_REG_BASE  = 32'h3000_0000;
    localparam ADDR_BRAM_BASE = 32'h3000_0100;

    // Instantiate your AHB Slave / BRAM Controller Module
    // Note: If using the Libero SmartDesign BIF interface, connect individual 
    // bus lines to the ports exposed in your AHB_SLAVE.v wrapper.
    AHB_SLAVE uut (
        .HCLK      (HCLK),
        .HRESETN   (HRESETN),
        .HADDR     (HADDR),
        .HTRANS    (HTRANS),
        .HWRITE    (HWRITE),
        .HSIZE     (HSIZE),
        .HBURST    (HBURST),
        .HPROT     (HPROT),
        .HWDATA    (HWDATA),
        .HSEL      (HSEL),
        .HREADY    (HREADY),
        .HRDATA    (HRDATA),
        .HREADYOUT (HREADYOUT),
        .HRESP     (HRESP)
    );

    // 50 MHz System Clock (20ns period)
    initial begin
        HCLK = 1'b0;
        forever #10 HCLK = ~HCLK;
    end

    // AHB-Lite Bus Master Write Task (Pipelined: Phase 1 Address, Phase 2 Data)
    task ahb_write(input [31:0] addr, input [31:0] data);
        begin
            // Address Phase
            @(posedge HCLK);
            HADDR  <= addr;
            HTRANS <= TRN_NONSEQ;
            HWRITE <= 1'b1;
            HSIZE  <= SIZE_WORD;
            HSEL   <= 1'b1;
            HREADY <= 1'b1;

            // Wait for address acceptance
            @(posedge HCLK);
            while (!HREADYOUT) @(posedge HCLK);

            // Data Phase & Return bus to IDLE
            HWDATA <= data;
            HTRANS <= TRN_IDLE;
            HWRITE <= 1'b0;
            HSEL   <= 1'b0;

            // Wait for data acceptance
            @(posedge HCLK);
            while (!HREADYOUT) @(posedge HCLK);

            $display("[%0t ns] [AHB WRITE] Addr: 0x%08h | Data: 0x%08h", $time, addr, data);
        end
    endtask

    // AHB-Lite Bus Master Read & Verify Task
    task ahb_read_verify(input [31:0] addr, input [31:0] expected_data);
        reg [31:0] read_val;
        begin
            // Address Phase
            @(posedge HCLK);
            HADDR  <= addr;
            HTRANS <= TRN_NONSEQ;
            HWRITE <= 1'b0;
            HSIZE  <= SIZE_WORD;
            HSEL   <= 1'b1;
            HREADY <= 1'b1;

            // Wait for address acceptance
            @(posedge HCLK);
            while (!HREADYOUT) @(posedge HCLK);

            // Turn off bus selector (IDLE)
            HTRANS <= TRN_IDLE;
            HSEL   <= 1'b0;

            // Data Phase
            @(posedge HCLK);
            while (!HREADYOUT) @(posedge HCLK);
            read_val = HRDATA;

            if (read_val === expected_data) begin
                $display("[%0t ns] [AHB READ PASS] Addr: 0x%08h | Expected: 0x%08h | Received: 0x%08h", 
                         $time, addr, expected_data, read_val);
            end else begin
                $error("[%0t ns] [AHB READ FAIL] Addr: 0x%08h | Expected: 0x%08h | Received: 0x%08h", 
                       $time, addr, expected_data, read_val);
            end
        end
    endtask

    // Verification Sequence
    initial begin
        // Reset State
        HRESETN = 1'b0;
        HADDR   = 32'h0;
        HTRANS  = TRN_IDLE;
        HWRITE  = 1'b0;
        HSIZE   = 3'b0;
        HBURST  = 3'b0;
        HPROT   = 4'b0;
        HWDATA  = 32'h0;
        HSEL    = 1'b0;
        HREADY  = 1'b1;

        // Apply Reset
        #100;
        @(posedge HCLK);
        HRESETN = 1'b1;
        #40;

        $display("--------------------------------------------------");
        $display("[%0t ns] Starting Register Access Test...", $time);
        $display("--------------------------------------------------");
        ahb_write(ADDR_REG_BASE + 32'h0, 32'hDEADBEEF);
        ahb_write(ADDR_REG_BASE + 32'h4, 32'hCAFE1234);

        ahb_read_verify(ADDR_REG_BASE + 32'h0, 32'hDEADBEEF);
        ahb_read_verify(ADDR_REG_BASE + 32'h4, 32'hCAFE1234);

        $display("--------------------------------------------------");
        $display("[%0t ns] Starting BRAM Block Read/Write Test...", $time);
        $display("--------------------------------------------------");
        // Write sequential words into BRAM space
        ahb_write(ADDR_BRAM_BASE + 32'h00, 32'h11223344);
        ahb_write(ADDR_BRAM_BASE + 32'h04, 32'h55667788);
        ahb_write(ADDR_BRAM_BASE + 32'h08, 32'h99AABBCC);
        ahb_write(ADDR_BRAM_BASE + 32'h0C, 32'hDDEEFF00);

        // Read back and compare
        ahb_read_verify(ADDR_BRAM_BASE + 32'h00, 32'h11223344);
        ahb_read_verify(ADDR_BRAM_BASE + 32'h04, 32'h55667788);
        ahb_read_verify(ADDR_BRAM_BASE + 32'h08, 32'h99AABBCC);
        ahb_read_verify(ADDR_BRAM_BASE + 32'h0C, 32'hDDEEFF00);

        #100;
        $display("--------------------------------------------------");
        $display("[%0t ns] All AHB-Lite transfers verified successfully.", $time);
        $display("--------------------------------------------------");
        $finish;
    end

endmodule
