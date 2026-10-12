
`timescale 1ns / 1ps

module tb_axi_accelerator_slave;

    reg         clk;
    reg         resetn;

    // AXI write address channel
    reg  [5:0]  awaddr;
    reg  [2:0]  awprot;
    reg         awvalid;
    wire        awready;

    // AXI write data channel
    reg  [31:0] wdata;
    reg  [3:0]  wstrb;
    reg         wvalid;
    wire        wready;

    // AXI write response channel
    wire [1:0]  bresp;
    wire        bvalid;
    reg         bready;

    // AXI read address channel
    reg  [5:0]  araddr;
    reg  [2:0]  arprot;
    reg         arvalid;
    wire        arready;

    // AXI read data channel
    wire [31:0] rdata;
    wire [1:0]  rresp;
    wire        rvalid;
    reg         rready;

    reg [31:0] read_value;
    integer i;
    integer timeout_count;

    // ------------------------------------------------
    // DUT: Design Under Test
    // Module name must match your RTL module.
    // ------------------------------------------------

    axi_accelerator_slave dut (
        .s00_axi_aclk    (clk),
        .s00_axi_aresetn (resetn),

        .s00_axi_awaddr  (awaddr),
        .s00_axi_awprot  (awprot),
        .s00_axi_awvalid (awvalid),
        .s00_axi_awready (awready),

        .s00_axi_wdata   (wdata),
        .s00_axi_wstrb   (wstrb),
        .s00_axi_wvalid  (wvalid),
        .s00_axi_wready  (wready),

        .s00_axi_bresp   (bresp),
        .s00_axi_bvalid  (bvalid),
        .s00_axi_bready  (bready),

        .s00_axi_araddr  (araddr),
        .s00_axi_arprot  (arprot),
        .s00_axi_arvalid (arvalid),
        .s00_axi_arready (arready),

        .s00_axi_rdata   (rdata),
        .s00_axi_rresp   (rresp),
        .s00_axi_rvalid  (rvalid),
        .s00_axi_rready  (rready)
    );

    // 100 MHz clock: 10 ns period
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // ------------------------------------------------
    // AXI WRITE TASK
    // Holds AWVALID and WVALID until each handshake.
    // The address and data channels are tracked
    // independently, as required by AXI4-Lite.
    // ------------------------------------------------

    task axi_write;
        input [5:0]  address;
        input [31:0] data;
        reg aw_done;
        reg w_done;
        begin
            @(negedge clk);
            awaddr  = address;
            awprot  = 3'b000;
            awvalid = 1'b1;

            wdata   = data;
            wstrb   = 4'b1111;
            wvalid  = 1'b1;

            aw_done = 1'b0;
            w_done  = 1'b0;

            while (!aw_done || !w_done) begin
                @(posedge clk);

                if (!aw_done && awvalid && awready)
                    aw_done = 1'b1;

                if (!w_done && wvalid && wready)
                    w_done = 1'b1;
            end

            @(negedge clk);
            awvalid = 1'b0;
            wvalid  = 1'b0;

            // Wait for the write response.
            while (bvalid !== 1'b1)
                @(negedge clk);

            if (bresp !== 2'b00) begin
                $display("FAIL: Write response error at %h",
                         address);
                $finish;
            end

            bready = 1'b1;
            @(negedge clk);
            bready = 1'b0;
        end
    endtask

    // ------------------------------------------------
    // AXI READ TASK
    // ------------------------------------------------

   
    // ------------------------------------------------
    // AXI READ TASK - Verilog-compatible
    // ------------------------------------------------

    task axi_read;
        input [5:0] address;
        output [31:0] data;

        reg ar_done;

        begin
            ar_done = 1'b0;
            data = 32'b0;

            // Present the read address.
            @(negedge clk);
            araddr  = address;
            arprot  = 3'b000;
            arvalid = 1'b1;

            // Wait until the address handshake completes.
            while (!ar_done) begin
                @(posedge clk);

                if (arvalid && arready)
                    ar_done = 1'b1;
            end

            // Deassert ARVALID after the handshake.
            @(negedge clk);
            arvalid = 1'b0;

            // Wait for the read response.
            while (rvalid !== 1'b1) begin
                @(negedge clk);
            end

            // Capture the response data.
            data = rdata;

            if (rresp !== 2'b00) begin
                $display("FAIL: Read response error at %h",
                         address);
                $finish;
            end

            // Accept the read response.
            rready = 1'b1;
            @(negedge clk);
            rready = 1'b0;
        end
    endtask


    // ------------------------------------------------
    // MAIN TEST SEQUENCE
    // ------------------------------------------------

    initial begin
        resetn  = 1'b0;

        awaddr  = 0;
        awprot  = 0;
        awvalid = 0;

        wdata   = 0;
        wstrb   = 0;
        wvalid  = 0;
        bready  = 0;

        araddr  = 0;
        arprot  = 0;
        arvalid = 0;
        rready  = 0;

        read_value   = 0;
        timeout_count = 0;

        $display("--------------------------------------");
        $display(" AXI ACCELERATOR SIMULATION START");
        $display("--------------------------------------");

        // Apply reset.
        repeat (5) @(negedge clk);
        resetn = 1'b1;
        repeat (3) @(negedge clk);

        $display("TEST 1: Write matrix A");

        // A = | 1  2 |
        //     | 3  4 |

        axi_write(6'h00, 32'd1);
        axi_write(6'h04, 32'd2);
        axi_write(6'h08, 32'd3);
        axi_write(6'h0C, 32'd4);

        $display("TEST 2: Write matrix B");

        // B = | 5  6 |
        //     | 7  8 |

        axi_write(6'h10, 32'd5);
        axi_write(6'h14, 32'd6);
        axi_write(6'h18, 32'd7);
        axi_write(6'h1C, 32'd8);

        // Check one operand register.
        axi_read(6'h00, read_value);

        if (read_value !== 32'd1) begin
            $display("FAIL: A0 readback = %h",
                     read_value);
            $finish;
        end

        $display("PASS: Operand register readback");

        // CONTROL register, bit 0 = START.
        $display("TEST 3: Start multiplication");

        axi_write(6'h20, 32'h00000001);

        // Poll STATUS:
        // bit 0 = DONE
        // bit 1 = BUSY

        $display("TEST 4: Poll completion status");

        timeout_count = 0;
        read_value = 0;

        while ((read_value[0] !== 1'b1) &&
               (timeout_count < 30)) begin
            axi_read(6'h24, read_value);
            timeout_count = timeout_count + 1;
        end

        if (read_value[0] !== 1'b1) begin
            $display("FAIL: Timeout waiting for DONE");
            $finish;
        end

        if (read_value[1] !== 1'b0) begin
            $display("FAIL: BUSY still asserted after DONE");
            $finish;
        end

        $display("PASS: Accelerator completed");

        // Read the four output registers.
        $display("TEST 5: Check multiplication results");

        axi_read(6'h28, read_value);
        $display("C0 = %0d (expected 19)", read_value);
        if (read_value !== 32'd19) begin
            $display("FAIL: C0 mismatch");
            $finish;
        end

        axi_read(6'h2C, read_value);
        $display("C1 = %0d (expected 22)", read_value);
        if (read_value !== 32'd22) begin
            $display("FAIL: C1 mismatch");
            $finish;
        end

        axi_read(6'h30, read_value);
        $display("C2 = %0d (expected 43)", read_value);
        if (read_value !== 32'd43) begin
            $display("FAIL: C2 mismatch");
            $finish;
        end

        axi_read(6'h34, read_value);
        $display("C3 = %0d (expected 50)", read_value);
        if (read_value !== 32'd50) begin
            $display("FAIL: C3 mismatch");
            $finish;
        end

        $display("--------------------------------------");
        $display(" ALL ACCELERATOR TESTS PASSED");
        $display("--------------------------------------");

        $finish;
    end

    // Global simulation watchdog.
    initial begin
        #100000;
        $display("FAIL: Global simulation timeout");
        $finish;
    end

endmodule
