`timescale 1ns/1ps

module testbench;

    reg [3:0] a, b;
    reg [2:0] sel;

    wire [3:0] alu_out;

    reg [3:0] expected;

    integer pass_count;
    integer fail_count;


    // DUT
    alu dut_01 (
        .a(a),
        .b(b),
        .sel(sel),
        .alu_out(alu_out)
    );


    // Reusable self-checking task
    task check_result;

        begin

            // Reference model
            case (sel)

                3'b000: expected = a + b;
                3'b001: expected = a - b;
                3'b010: expected = a * b;
                3'b011: expected = a / b;
                3'b100: expected = a ^ b;
                3'b101: expected = ~a;
                3'b110: expected = a << b;
                3'b111: expected = a >> b;

                default: expected = 4'b0000;

            endcase


            // Small delay to allow DUT output to update
            #1;


            // Self-checking section
            if (expected === alu_out) begin

                $display(
                    "PASS : a=%b b=%b sel=%b Expected=%b Got=%b",
                    a, b, sel, expected, alu_out
                );

                pass_count = pass_count + 1;

            end
            else begin

                $display(
                    "FAIL : a=%b b=%b sel=%b Expected=%b Got=%b",
                    a, b, sel, expected, alu_out
                );

                fail_count = fail_count + 1;

            end

        end

    endtask


    initial begin

        pass_count = 0;
        fail_count = 0;


        // ADDITION
        a = 4'b0011;
        b = 4'b0010;
        sel = 3'b000;
        check_result;


        // SUBTRACTION
        a = 4'b1000;
        b = 4'b0011;
        sel = 3'b001;
        check_result;


        // MULTIPLICATION
        a = 4'b0011;
        b = 4'b0010;
        sel = 3'b010;
        check_result;


        // DIVISION
        a = 4'b1000;
        b = 4'b0010;
        sel = 3'b011;
        check_result;


        // XOR
        a = 4'b1010;
        b = 4'b1100;
        sel = 3'b100;
        check_result;


        // NOT
        a = 4'b1010;
        b = 4'b0000;
        sel = 3'b101;
        check_result;


        // SHIFT LEFT
        a = 4'b0011;
        b = 4'b0001;
        sel = 3'b110;
        check_result;


        // SHIFT RIGHT
        a = 4'b1100;
        b = 4'b0001;
        sel = 3'b111;
        check_result;


        // Final report
        $display("==============================================");
        $display("FINAL REPORT");
        $display("PASS = %0d", pass_count);
        $display("FAIL = %0d", fail_count);
        $display("==============================================");

        if (fail_count == 0)
            $display("ALL TESTS PASSED");
        else
            $display("SOME TESTS FAILED");


        #50;
        $finish;

    end
endmodule
