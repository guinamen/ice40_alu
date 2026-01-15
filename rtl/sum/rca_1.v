module rca_1 #(parameter integer WIDTH = 4) (
    input  wire [WIDTH-1:0] a, b,
    output wire [WIDTH-1:0] sum,
    output wire             cout
);
    // --- CAMINHO 1: A + B + 1 (CSA Otimizado) ---
    wire [WIDTH-1:0] s1_vec;
    wire [WIDTH-1:0] c1_vec; // Vetor completo

    // Bit 0: Lógica simplificada para Cin=1 (A + B + 1)
    assign s1_vec[0] = ~(a[0] ^ b[0]); // XNOR
    assign c1_vec[0] = a[0] | b[0];    // OR

    // Bits superiores: Lógica padrão de Half-Adder
    assign s1_vec[WIDTH-1:1] = a[WIDTH-1:1] ^ b[WIDTH-1:1];
    assign c1_vec[WIDTH-1:1] = a[WIDTH-1:1] & b[WIDTH-1:1];

    // Redução Final do Caminho 1
    // A soma interna usa apenas os bits [WIDTH-2:0] do vetor de carry deslocado.
    // O bit [WIDTH-1] (MSB) do c1_vec representa um carry gerado na última posição,
    // que deve ser propagado para o cout final.

    wire adder_cout;
    wire [WIDTH-1:0] adder_sum;

    // Soma principal ignorando o MSB do c1_vec no deslocamento
    assign {adder_cout, adder_sum} = s1_vec + {c1_vec[WIDTH-2:0], 1'b0};

    assign sum = adder_sum;

    // O cout final é o carry da soma OU o carry gerado diretamente pelo MSB (o bit que causava o warning)
    assign cout = adder_cout | c1_vec[WIDTH-1];

endmodule
