
`timescale 1ns / 1ps

module axi_accelerator_slave (
    input  wire        s00_axi_aclk,
    input  wire        s00_axi_aresetn,

    // AXI4-Lite write address channel
    input  wire [5:0]  s00_axi_awaddr,
    input  wire [2:0]  s00_axi_awprot,
    input  wire        s00_axi_awvalid,
    output wire        s00_axi_awready,

    // AXI4-Lite write data channel
    input  wire [31:0] s00_axi_wdata,
    input  wire [3:0]  s00_axi_wstrb,
    input  wire        s00_axi_wvalid,
    output wire        s00_axi_wready,

    // AXI4-Lite write response channel
    output reg  [1:0]  s00_axi_bresp,
    output reg         s00_axi_bvalid,
    input  wire        s00_axi_bready,

    // AXI4-Lite read address channel
    input  wire [5:0]  s00_axi_araddr,
    input  wire [2:0]  s00_axi_arprot,
    input  wire        s00_axi_arvalid,
    output wire        s00_axi_arready,

    // AXI4-Lite read data channel
    output reg  [31:0] s00_axi_rdata,
    output reg  [1:0]  s00_axi_rresp,
    output reg         s00_axi_rvalid,
    input  wire        s00_axi_rready
);

    // ----------------------------------------------------
    // Register map: byte offsets
    //
    // 0x00 - 0x0C : A0, A1, A2, A3
    // 0x10 - 0x1C : B0, B1, B2, B3
    // 0x20        : CONTROL (bit 0 = START)
    // 0x24        : STATUS  (bit 0 = DONE, bit 1 = BUSY)
    // 0x28 - 0x34 : C0, C1, C2, C3
    //
    // Matrix layout:
    // A = | A0 A1 |    B = | B0 B1 |
    //     | A2 A3 |        | B2 B3 |
    //
    // C0 = A0*B0 + A1*B2
    // C1 = A0*B1 + A1*B3
    // C2 = A2*B0 + A3*B2
    // C3 = A2*B1 + A3*B3
    // ----------------------------------------------------

    reg [31:0] reg_a0, reg_a1, reg_a2, reg_a3;
    reg [31:0] reg_b0, reg_b1, reg_b2, reg_b3;

    reg [31:0] reg_c0, reg_c1, reg_c2, reg_c3;

    reg busy;
    reg done;
    reg start_pulse;

    // ----------------------------------------------------
    // AXI write channel: capture AW and W independently
    // ----------------------------------------------------

    reg        aw_captured;
    reg        w_captured;

    reg [5:0]  awaddr_buf;
    reg [31:0] wdata_buf;
    reg [3:0]  wstrb_buf;

    integer byte_index;

    assign s00_axi_awready = !aw_captured &&
                             !s00_axi_bvalid;

    assign s00_axi_wready  = !w_captured &&
                             !s00_axi_bvalid;

    always @(posedge s00_axi_aclk) begin
        if (!s00_axi_aresetn) begin
            aw_captured <= 1'b0;
            w_captured  <= 1'b0;

            awaddr_buf <= 6'b0;
            wdata_buf  <= 32'b0;
            wstrb_buf  <= 4'b0;

            s00_axi_bvalid <= 1'b0;
            s00_axi_bresp  <= 2'b00;

            start_pulse <= 1'b0;

            reg_a0 <= 32'b0;
            reg_a1 <= 32'b0;
            reg_a2 <= 32'b0;
            reg_a3 <= 32'b0;

            reg_b0 <= 32'b0;
            reg_b1 <= 32'b0;
            reg_b2 <= 32'b0;
            reg_b3 <= 32'b0;
        end else begin
            // START is a one-cycle pulse.
            start_pulse <= 1'b0;

            // Capture address independently.
            if (s00_axi_awvalid && s00_axi_awready) begin
                awaddr_buf <= s00_axi_awaddr;
                aw_captured <= 1'b1;
            end

            // Capture data and byte strobes independently.
            if (s00_axi_wvalid && s00_axi_wready) begin
                wdata_buf <= s00_axi_wdata;
                wstrb_buf <= s00_axi_wstrb;
                w_captured <= 1'b1;
            end

            // Consume the previous write response.
            if (s00_axi_bvalid && s00_axi_bready)
                s00_axi_bvalid <= 1'b0;

            // Execute only after both channels are captured.
            if (aw_captured && w_captured &&
                !s00_axi_bvalid) begin

                case (awaddr_buf[5:2])

                    4'd0: begin
                        for (byte_index = 0; byte_index < 4;
                             byte_index = byte_index + 1)
                            if (wstrb_buf[byte_index])
                                reg_a0[byte_index*8 +: 8]
                                    <= wdata_buf[byte_index*8 +: 8];
                    end

                    4'd1: begin
                        for (byte_index = 0; byte_index < 4;
                             byte_index = byte_index + 1)
                            if (wstrb_buf[byte_index])
                                reg_a1[byte_index*8 +: 8]
                                    <= wdata_buf[byte_index*8 +: 8];
                    end

                    4'd2: begin
                        for (byte_index = 0; byte_index < 4;
                             byte_index = byte_index + 1)
                            if (wstrb_buf[byte_index])
                                reg_a2[byte_index*8 +: 8]
                                    <= wdata_buf[byte_index*8 +: 8];
                    end

                    4'd3: begin
                        for (byte_index = 0; byte_index < 4;
                             byte_index = byte_index + 1)
                            if (wstrb_buf[byte_index])
                                reg_a3[byte_index*8 +: 8]
                                    <= wdata_buf[byte_index*8 +: 8];
                    end

                    4'd4: begin
                        for (byte_index = 0; byte_index < 4;
                             byte_index = byte_index + 1)
                            if (wstrb_buf[byte_index])
                                reg_b0[byte_index*8 +: 8]
                                    <= wdata_buf[byte_index*8 +: 8];
                    end

                    4'd5: begin
                        for (byte_index = 0; byte_index < 4;
                             byte_index = byte_index + 1)
                            if (wstrb_buf[byte_index])
                                reg_b1[byte_index*8 +: 8]
                                    <= wdata_buf[byte_index*8 +: 8];
                    end

                    4'd6: begin
                        for (byte_index = 0; byte_index < 4;
                             byte_index = byte_index + 1)
                            if (wstrb_buf[byte_index])
                                reg_b2[byte_index*8 +: 8]
                                    <= wdata_buf[byte_index*8 +: 8];
                    end

                    4'd7: begin
                        for (byte_index = 0; byte_index < 4;
                             byte_index = byte_index + 1)
                            if (wstrb_buf[byte_index])
                                reg_b3[byte_index*8 +: 8]
                                    <= wdata_buf[byte_index*8 +: 8];
                    end

                    // CONTROL: write bit 0 to start.
                    4'd8: begin
                        if (wstrb_buf[0] && wdata_buf[0])
                            start_pulse <= 1'b1;
                    end

                    // STATUS and result registers are read-only.
                    default: begin
                    end

                endcase

                aw_captured <= 1'b0;
                w_captured  <= 1'b0;

                s00_axi_bresp  <= 2'b00; // OKAY
                s00_axi_bvalid <= 1'b1;
            end
        end
    end

    // ----------------------------------------------------
    // Matrix multiplication engine
    // One signed 16x16 multiplier, reused over 8 cycles.
    // ----------------------------------------------------

    localparam [3:0] IDLE    = 4'd0,
                     C0_FIRST  = 4'd1,
                     C0_SECOND = 4'd2,
                     C1_FIRST  = 4'd3,
                     C1_SECOND = 4'd4,
                     C2_FIRST  = 4'd5,
                     C2_SECOND = 4'd6,
                     C3_FIRST  = 4'd7,
                     C3_SECOND = 4'd8;

    reg [3:0] state;

    reg signed [15:0] a0_l, a1_l, a2_l, a3_l;
    reg signed [15:0] b0_l, b1_l, b2_l, b3_l;

    reg signed [15:0] mul_a, mul_b;

    reg signed [32:0] accumulator;

    wire signed [31:0] mul_a_ext;
    wire signed [31:0] mul_b_ext;
    wire signed [31:0] product;
    wire signed [32:0] product_ext;
    wire signed [32:0] accumulator_sum;

    assign mul_a_ext = {{16{mul_a[15]}}, mul_a};
    assign mul_b_ext = {{16{mul_b[15]}}, mul_b};

    assign product = mul_a_ext * mul_b_ext;

    assign product_ext = {product[31], product};
    assign accumulator_sum = accumulator + product_ext;

    // Select operands for the shared multiplier.
    always @* begin
        mul_a = 16'sd0;
        mul_b = 16'sd0;

        case (state)
            C0_FIRST: begin
                mul_a = a0_l; mul_b = b0_l;
            end
            C0_SECOND: begin
                mul_a = a1_l; mul_b = b2_l;
            end
            C1_FIRST: begin
                mul_a = a0_l; mul_b = b1_l;
            end
            C1_SECOND: begin
                mul_a = a1_l; mul_b = b3_l;
            end
            C2_FIRST: begin
                mul_a = a2_l; mul_b = b0_l;
            end
            C2_SECOND: begin
                mul_a = a3_l; mul_b = b2_l;
            end
            C3_FIRST: begin
                mul_a = a2_l; mul_b = b1_l;
            end
            C3_SECOND: begin
                mul_a = a3_l; mul_b = b3_l;
            end
            default: begin
                mul_a = 16'sd0;
                mul_b = 16'sd0;
            end
        endcase
    end

    always @(posedge s00_axi_aclk) begin
        if (!s00_axi_aresetn) begin
            state <= IDLE;
            busy  <= 1'b0;
            done  <= 1'b0;

            accumulator <= 33'sd0;

            a0_l <= 16'sd0; a1_l <= 16'sd0;
            a2_l <= 16'sd0; a3_l <= 16'sd0;
            b0_l <= 16'sd0; b1_l <= 16'sd0;
            b2_l <= 16'sd0; b3_l <= 16'sd0;

            reg_c0 <= 32'b0;
            reg_c1 <= 32'b0;
            reg_c2 <= 32'b0;
            reg_c3 <= 32'b0;
        end else begin
            case (state)

                IDLE: begin
                    busy <= 1'b0;

                    if (start_pulse) begin
                        // Snapshot inputs so they remain stable
                        // throughout the calculation.
                        a0_l <= reg_a0[15:0];
                        a1_l <= reg_a1[15:0];
                        a2_l <= reg_a2[15:0];
                        a3_l <= reg_a3[15:0];

                        b0_l <= reg_b0[15:0];
                        b1_l <= reg_b1[15:0];
                        b2_l <= reg_b2[15:0];
                        b3_l <= reg_b3[15:0];

                        done <= 1'b0;
                        busy <= 1'b1;
                        state <= C0_FIRST;
                    end
                end

                C0_FIRST: begin
                    accumulator <= product_ext;
                    state <= C0_SECOND;
                end

                C0_SECOND: begin
                    reg_c0 <= accumulator_sum[31:0];
                    state <= C1_FIRST;
                end

                C1_FIRST: begin
                    accumulator <= product_ext;
                    state <= C1_SECOND;
                end

                C1_SECOND: begin
                    reg_c1 <= accumulator_sum[31:0];
                    state <= C2_FIRST;
                end

                C2_FIRST: begin
                    accumulator <= product_ext;
                    state <= C2_SECOND;
                end

                C2_SECOND: begin
                    reg_c2 <= accumulator_sum[31:0];
                    state <= C3_FIRST;
                end

                C3_FIRST: begin
                    accumulator <= product_ext;
                    state <= C3_SECOND;
                end

                C3_SECOND: begin
                    reg_c3 <= accumulator_sum[31:0];
                    busy <= 1'b0;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    busy <= 1'b0;
                end

            endcase
        end
    end

    // ----------------------------------------------------
    // AXI4-Lite read channel
    // ----------------------------------------------------

    reg [31:0] read_mux;

    always @* begin
        read_mux = 32'b0;

        case (s00_axi_araddr[5:2])
            4'd0:  read_mux = reg_a0;
            4'd1:  read_mux = reg_a1;
            4'd2:  read_mux = reg_a2;
            4'd3:  read_mux = reg_a3;

            4'd4:  read_mux = reg_b0;
            4'd5:  read_mux = reg_b1;
            4'd6:  read_mux = reg_b2;
            4'd7:  read_mux = reg_b3;

            4'd8:  read_mux = 32'b0;
            4'd9:  read_mux = {30'b0, busy, done};

            4'd10: read_mux = reg_c0;
            4'd11: read_mux = reg_c1;
            4'd12: read_mux = reg_c2;
            4'd13: read_mux = reg_c3;

            default: read_mux = 32'b0;
        endcase
    end

    assign s00_axi_arready = !s00_axi_rvalid;

    always @(posedge s00_axi_aclk) begin
        if (!s00_axi_aresetn) begin
            s00_axi_rdata  <= 32'b0;
            s00_axi_rresp  <= 2'b00;
            s00_axi_rvalid <= 1'b0;
        end else begin
            if (s00_axi_rvalid && s00_axi_rready)
                s00_axi_rvalid <= 1'b0;

            if (s00_axi_arvalid && s00_axi_arready) begin
                s00_axi_rdata  <= read_mux;
                s00_axi_rresp  <= 2'b00; // OKAY
                s00_axi_rvalid <= 1'b1;
            end
        end
    end

endmodule
