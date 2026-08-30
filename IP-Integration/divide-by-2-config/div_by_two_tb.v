`timescale 1ns/1ps
module testbench;

    // Testbench signals
    reg  clk_in;
    wire clk_out;
    wire locked;

    // Instantiate the SmartDesign component
    clock_div dut (
        .clk_in  (clk_in),
        .clk_out (clk_out),
        .locked  (locked)
    );

    // Generate 100 MHz input clock
    // Period = 10 ns
    initial begin
        clk_in = 1'b0;

        forever begin
            #5 clk_in = ~clk_in;
        end
    end

    // Simulation control
    initial begin

        // Run long enough for CCC to lock
        #50000;

        $finish;
    end

endmodule
