`timescale 1ns/1ps

module g06_tb;
    logic clk = 0;
    logic rst_n = 0;
    logic valid_in = 0;
    logic [7:0] x = 0;
    logic [7:0] y;
    logic valid_out;

    integer sample_no = 0;

    g06_iir_half dut (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(valid_in),
        .x(x),
        .y(y),
        .valid_out(valid_out)
    );

    always #5 clk = ~clk;

    task automatic send(
        input logic [7:0] xin,
        input logic [7:0] expected
    );
        begin
            @(negedge clk);
            x = xin;
            valid_in = 1;

            @(posedge clk);
            #1;

            if (valid_out !== 1'b1)
                $fatal(1, "FAIL: valid_out missing");

            if (y !== expected)
                $fatal(1, "FAIL: x=%0d y=%0d expected=%0d",
                       $signed(x), $signed(y), $signed(expected));

            $display("SAMPLE %0d: x=%0d y=%0d PASS",
                     sample_no, $signed(x), $signed(y));

            sample_no = sample_no + 1;
            valid_in = 0;
        end
    endtask

    initial begin
        $dumpfile("g06_iir_wave.vcd");
        $dumpvars(0, g06_tb);

        repeat (2) @(negedge clk);
        rst_n = 1;

        $display("TEST 1: STEP INPUT x=100");
        send(100, 50);
        send(100, 75);
        send(100, 87);
        send(100, 93);
        send(100, 96);
        send(100, 98);
        send(100, 99);
        send(100, 99);

        $display("TEST 2: CHANGE INPUT");
        send(1, 50);
        send(1, 25);

        $display("TEST 3: NEGATIVE INPUT");
        send(-8'sd128, -8'sd52);

        @(negedge clk);
        valid_in = 0;
        repeat (2) @(posedge clk);
        #1;
        if (valid_out !== 0)
            $fatal(1, "FAIL: valid_out during gap");
        $display("TEST 4: VALID GAP PASS");

        @(negedge clk);
        rst_n = 0;
        valid_in = 0;
        repeat (2) @(negedge clk);
        rst_n = 1;

        $display("TEST 5: RESET AND SMALL INPUT");
        repeat (12)
            send(1, 0);

        $display("ALL TESTS PASSED: %0d samples", sample_no);
        $finish;
    end
endmodule
