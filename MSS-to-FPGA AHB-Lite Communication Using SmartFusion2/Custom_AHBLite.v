`timescale 1ns/1ps

module AHB_SLAVE (
    // Clock and Reset
    input  wire        HCLK,
    input  wire        HRESETN,

    // AHB-Lite Slave Inputs
    input  wire        HSEL,
    input  wire [31:0] HADDR,
    input  wire [1:0]  HTRANS,
    input  wire        HWRITE,
    input  wire [2:0]  HSIZE,
    input  wire [2:0]  HBURST,
    input  wire [3:0]  HPROT,
    input  wire [31:0] HWDATA,
    input  wire        HREADY,

    // AHB-Lite Slave Outputs
    output wire [31:0] HRDATA,
    output wire        HREADYOUT,
    output wire        HRESP
);


    reg [31:0] address_reg;
    reg        write_reg;
    reg        transfer_valid;

    reg [31:0] register0;
    reg [31:0] register1;
    reg [31:0] register2;
    reg [31:0] register3;

    wire valid_transfer;

    assign valid_transfer =
        HSEL &&
        HTRANS[1] &&
        HREADY;


    // Slave is always ready

    assign HREADYOUT = 1'b1;

    // Always respond OKAY

    assign HRESP = 1'b0;

    // Address and control phase
    always @(posedge HCLK or negedge HRESETN) begin

        if (!HRESETN) begin

            address_reg    <= 32'h00000000;
            write_reg      <= 1'b0;
            transfer_valid <= 1'b0;

        end
        else begin

            // Store current transfer information
            transfer_valid <= valid_transfer;

            if (valid_transfer) begin

                address_reg <= HADDR;
                write_reg   <= HWRITE;

            end

        end

    end

    // Write data phase


    always @(posedge HCLK or negedge HRESETN) begin

        if (!HRESETN) begin

            register0 <= 32'h00000000;
            register1 <= 32'h00000000;
            register2 <= 32'h00000000;
            register3 <= 32'h00000000;

        end
        else begin

            if (transfer_valid && write_reg) begin

                case (address_reg[3:2])

                    2'b00: register0 <= HWDATA;
                    2'b01: register1 <= HWDATA;
                    2'b10: register2 <= HWDATA;
                    2'b11: register3 <= HWDATA;

                    default: begin
                        register0 <= register0;
                    end

                endcase

            end

        end

    end

    // Read data


    reg [31:0] read_data;

    always @(*) begin

        case (address_reg[3:2])

            2'b00: read_data = register0;
            2'b01: read_data = register1;
            2'b10: read_data = register2;
            2'b11: read_data = register3;

            default: read_data = 32'h00000000;

        endcase

    end


    assign HRDATA = read_data;


endmodule
