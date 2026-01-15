module cs_block #(parameter integer WIDTH = 4) (
    input  wire [WIDTH-1:0] a, b,
    output wire [WIDTH-1:0] sum0, sum1,
    output wire             G, P,
    output wire             c0, c1
);
    rca_0 #(WIDTH) rca0 (.a(a), .b(b), .sum(sum0), .cout(c0));
    rca_1 #(WIDTH) rca1 (.a(a), .b(b), .sum(sum1), .cout(c1));
    assign G = c0;
    assign P = c1 ^ c0;
endmodule
