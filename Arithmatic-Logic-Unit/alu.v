`timescale 1ns/1ps

module alu ( 
             input wire [3:0] a,
             input wire [3:0] b,
             input wire [2:0] sel,
             output reg [3: 0] alu_out
             );
             
             
             always @( * ) begin
             
             case ( sel )
             
             3'b000 : alu_out = a + b;
             3'b001 : alu_out = a - b;
             3'b010 : alu_out = a * b;
             3'b011 : alu_out = a / b;
             3'b100 : alu_out = a ^ b;
             3'b101 : alu_out = ~a;
             3'b110 : alu_out = a << b;
             3'b111 : alu_out = a >> b;
             
             endcase 
             
             end
             endmodule
             
             
             
             
