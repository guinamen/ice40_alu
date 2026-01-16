module unit_logic #(parameter WIDTH = 8) (
    input  c_and,
    input  c_or,
    input  c_xor,
    input  [WIDTH-1:0] a,
    input  [WIDTH-1:0] b,
    output [WIDTH-1:0] out
);
    assign out = ({WIDTH{c_and}} & (a & b)) |
                 ({WIDTH{c_or }} & (a | b)) |
                 ({WIDTH{c_xor}} & (a ^ b));
endmodule
