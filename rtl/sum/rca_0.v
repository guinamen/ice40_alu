module rca_0 #(parameter integer WIDTH = 4) (
    input  wire [WIDTH-1:0] a, b,
    output wire [WIDTH-1:0] sum,
    output wire             cout
);
    assign {cout, sum} = a + b;
endmodule
