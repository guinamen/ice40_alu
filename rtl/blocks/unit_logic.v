// --- Unidade Lógica (Máscaras + XOR) ---
module unit_logic #(parameter WIDTH = 8) (
    input  c_and,
    input  c_or,
    input  c_xor,
    input  c_inv,
    input  [WIDTH-1:0] a,
    input  [WIDTH-1:0] b,
    output [WIDTH-1:0] out
);
    wire [WIDTH-1:0] res_base = ({WIDTH{c_and}} & (a & b)) |
                                ({WIDTH{c_or }} & (a | b)) |
                                ({WIDTH{c_xor}} & (a ^ b));
    // Inversão condicional rápida via XOR
    assign out = res_base ^ {WIDTH{c_inv}};
endmodule
