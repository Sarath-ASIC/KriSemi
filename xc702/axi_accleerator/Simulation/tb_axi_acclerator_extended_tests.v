    // Add This code by replacing the initial begin block in the MAIN TEST 
    // -------------------------------------------------------------------
    // EXTENDED VERIFICATION TEST SEQUENCE
    // -------------------------------------------------------------------

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

        read_value    = 0;
        timeout_count = 0;

        $display("======================================");
        $display(" EXTENDED AXI ACCELERATOR TEST");
        $display("======================================");

        // --------------------------------------------
        // TEST 1: Reset and register initialization
        // --------------------------------------------

        $display("\nTEST 1: Reset behavior");

        repeat (5) @(negedge clk);
        resetn = 1'b1;
        repeat (3) @(negedge clk);

        // Write a nonzero value.
        axi_write(6'h00, 32'd123);
        axi_read(6'h00, read_value);

        if (read_value !== 32'd123) begin
            $display("FAIL: Initial register write/read");
            $finish;
        end

        // Apply reset again.
        @(negedge clk);
        resetn = 1'b0;

        repeat (5) @(negedge clk);
        resetn = 1'b1;

        repeat (3) @(negedge clk);

        axi_read(6'h00, read_value);

        if (read_value !== 32'd0) begin
            $display("FAIL: Register did not clear on reset");
            $finish;
        end

        $display("PASS: Reset clears operand registers");

        // --------------------------------------------
        // TEST 2: Positive matrix multiplication
        // --------------------------------------------

        $display("\nTEST 2: Positive matrix multiplication");

        // A = | 1  2 |
        //     | 3  4 |

        axi_write(6'h00, 32'd1);
        axi_write(6'h04, 32'd2);
        axi_write(6'h08, 32'd3);
        axi_write(6'h0C, 32'd4);

        // B = | 5  6 |
        //     | 7  8 |

        axi_write(6'h10, 32'd5);
        axi_write(6'h14, 32'd6);
        axi_write(6'h18, 32'd7);
        axi_write(6'h1C, 32'd8);

        // Start computation.
        axi_write(6'h20, 32'h00000001);

        // Poll STATUS until DONE or timeout.
        timeout_count = 0;
        read_value = 0;

        while ((read_value[0] !== 1'b1) &&
               (timeout_count < 30)) begin
            axi_read(6'h24, read_value);
            timeout_count = timeout_count + 1;
        end

        if (read_value[0] !== 1'b1) begin
            $display("FAIL: Positive multiplication timeout");
            $finish;
        end

        // Verify all four results.
        axi_read(6'h28, read_value);
        if (read_value !== 32'd19) begin
            $display("FAIL: Positive C0 = %h", read_value);
            $finish;
        end

        axi_read(6'h2C, read_value);
        if (read_value !== 32'd22) begin
            $display("FAIL: Positive C1 = %h", read_value);
            $finish;
        end

        axi_read(6'h30, read_value);
        if (read_value !== 32'd43) begin
            $display("FAIL: Positive C2 = %h", read_value);
            $finish;
        end

        axi_read(6'h34, read_value);
        if (read_value !== 32'd50) begin
            $display("FAIL: Positive C3 = %h", read_value);
            $finish;
        end

        $display("PASS: Positive multiplication");

        // --------------------------------------------
        // TEST 3: Signed negative operands
        // --------------------------------------------

        $display("\nTEST 3: Signed negative multiplication");

        // A = | -1  -2 |
        //     | -3  -4 |
        //
        // B = |  5   6 |
        //     |  7   8 |
        //
        // Expected C:
        //     | -19  -22 |
        //     | -43  -50 |

        axi_write(6'h00, 32'hFFFFFFFF); // -1
        axi_write(6'h04, 32'hFFFFFFFE); // -2
        axi_write(6'h08, 32'hFFFFFFFD); // -3
        axi_write(6'h0C, 32'hFFFFFFFC); // -4

        axi_write(6'h10, 32'd5);
        axi_write(6'h14, 32'd6);
        axi_write(6'h18, 32'd7);
        axi_write(6'h1C, 32'd8);

        // Start second computation.
        axi_write(6'h20, 32'h00000001);

        // Poll for DONE.
        timeout_count = 0;
        read_value = 0;

        while ((read_value[0] !== 1'b1) &&
               (timeout_count < 30)) begin
            axi_read(6'h24, read_value);
            timeout_count = timeout_count + 1;
        end

        if (read_value[0] !== 1'b1) begin
            $display("FAIL: Signed multiplication timeout");
            $finish;
        end

        // Check two's-complement output values.
        axi_read(6'h28, read_value);
        if (read_value !== 32'hFFFFFFED) begin
            $display("FAIL: Signed C0 = %h", read_value);
            $finish;
        end

        axi_read(6'h2C, read_value);
        if (read_value !== 32'hFFFFFFEA) begin
            $display("FAIL: Signed C1 = %h", read_value);
            $finish;
        end

        axi_read(6'h30, read_value);
        if (read_value !== 32'hFFFFFFD5) begin
            $display("FAIL: Signed C2 = %h", read_value);
            $finish;
        end

        axi_read(6'h34, read_value);
        if (read_value !== 32'hFFFFFFCE) begin
            $display("FAIL: Signed C3 = %h", read_value);
            $finish;
        end

        $display("PASS: Signed negative multiplication");

        // --------------------------------------------
        // TEST 4: Final status check
        // --------------------------------------------

        $display("\nTEST 4: Final status");

        axi_read(6'h24, read_value);

        if ((read_value[0] !== 1'b1) ||
            (read_value[1] !== 1'b0)) begin
            $display("FAIL: Incorrect final status = %h",
                     read_value);
            $finish;
        end

        $display("PASS: DONE=1 and BUSY=0");

        // --------------------------------------------
        // FINAL RESULT
        // --------------------------------------------

        $display("\n======================================");
        $display(" ALL EXTENDED TESTS PASSED");
        $display("======================================");

        $finish;
    end
