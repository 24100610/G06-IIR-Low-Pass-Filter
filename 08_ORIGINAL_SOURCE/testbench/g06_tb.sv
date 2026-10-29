module g06_tb;
    logic clk, rst_n, valid_in;
    logic [7:0] x;
    logic [7:0] y;
    logic valid_out;

    g06_iir_half dut(
        .clk(clk), .rst_n(rst_n), .valid_in(valid_in),
        .x(x), .y(y), .valid_out(valid_out)
    );

    always #5 clk = ~clk;

    task automatic send(input logic [7:0] xin,
                        input logic [7:0] expected);
        begin
            x=xin;
            valid_in=1'b1;
            @(posedge clk); #1;
            assert(valid_out)
                else $fatal(1,"valid_out missing");
            assert(y==expected)
                else $fatal(1,"y mismatch: got=%0d expected=%0d",
                            $signed(y),$signed(expected));
            valid_in=1'b0;
        end
    endtask

    initial begin
        clk=0; rst_n=0; valid_in=0; x=0;
        repeat(2) @(posedge clk);
        rst_n=1;

        // Positive step x=100.
        send(8'sd100,8'sd50);
        send(8'sd100,8'sd75);
        send(8'sd100,8'sd87);
        send(8'sd100,8'sd93);
        send(8'sd100,8'sd96);
        send(8'sd100,8'sd98);
        send(8'sd100,8'sd99);
        send(8'sd100,8'sd99);

        // Low-value standing still.
        send(8'sd1,8'sd50);
        send(8'sd1,8'sd25);

        // Boundary negative case.
        send(-8'sd128,-8'sd51);

        // Valid gap.
        valid_in=0;
        repeat(2) @(posedge clk); #1;
        assert(!valid_out) else $fatal(1,"valid gap produced output");

        $display("G06 TB completed");
        $finish;
    end
endmodule
