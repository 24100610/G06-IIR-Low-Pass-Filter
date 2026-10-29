`ifdef G06_SVA

// Scaffold-level property. Exact cycle semantics must be frozen for the course wrapper.
assert valid_output_requires_input:
    assert property (@(posedge clk) valid_out |-> $past(valid_in));

`endif
