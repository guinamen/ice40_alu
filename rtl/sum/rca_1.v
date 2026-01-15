module rca_1 #(parameter integer WIDTH = 4) (
    input  wire [WIDTH-1:0] a, b,
    output wire [WIDTH-1:0] sum,
    output wire             cout
);
    //assign {cout, sum} = a + b + {{(WIDTH-1){1'b0}}, 1'b1};
    // --- CAMINHO 1: A + B + 1 (CSA Otimizado) ---
    wire [WIDTH-1:0] s1_vec;
    wire [WIDTH-1:0] c1_vec;

    // Bit 0: Lógica simplificada para Cin=1
    assign s1_vec[0] = ~(a[0] ^ b[0]); // XNOR
    assign c1_vec[0] = a[0] | b[0];    // OR

    // Bits superiores: O terceiro operando é zero,
    // então o CSA simplifica para a própria estrutura da soma
    assign s1_vec[WIDTH-1:1] = a[WIDTH-1:1] ^ b[WIDTH-1:1];
    assign c1_vec[WIDTH-1:1] = a[WIDTH-1:1] & b[WIDTH-1:1];

    // Redução Final do Caminho 1
    //Sum1 = S1 + (C1 << 1)
    assign {cout, sum} = s1_vec + {c1_vec[WIDTH-2:0], 1'b0};
endmodule
