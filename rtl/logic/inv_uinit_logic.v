// --- Unidade Lógica (Máscaras + XOR) ---
module inv_uinit_logic #(parameter WIDTH = 8) (
    input  c_and,
    input  c_or,
    input  c_xor,
    input  c_inv,
    input  [WIDTH-1:0] a,
    input  [WIDTH-1:0] b,
    output [WIDTH-1:0] out
);
  wire [WIDTH-1:0] res_base;
  logic_unit(.c_and(c_and), .c_or(c_or), c_xor(c_xor),.a(a),.b(b),.out(res));
    // Inversão condicional rápida via XOR
  assign out = res_base ^ {WIDTH{c_inv}};
endmodule
