module g06_iir_half (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       valid_in,
    input  logic [7:0] x,
    output logic [7:0] y,
    output logic       valid_out
);

    logic signed [7:0] y_q;
    logic signed [8:0] sum_ext;
    logic signed [8:0] x_ext;
    logic signed [8:0] y_ext;
    logic signed [8:0] y_shift;

    always_comb begin
        x_ext   = {x[7], x};
        y_ext   = {y_q[7], y_q};
        sum_ext = x_ext + y_ext;
        y_shift = sum_ext >>> 1;
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            y_q      <= '0;
            y        <= '0;
            valid_out <= 1'b0;
        end else begin
            valid_out <= 1'b0;
            if (valid_in) begin
                y_q      <= y_shift[7:0];
                y        <= y_shift[7:0];
                valid_out <= 1'b1;
            end
        end
    end

endmodule
