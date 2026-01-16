// ---------------------------------------------------------
// Unidade Lógica Otimizada para LUT4
// Entradas: 4 (a, b, opcode[0], opcode[1]) -> Saída: 1
// Isso garante apenas 1 nível de atraso lógico.
// ---------------------------------------------------------
module unit_logic #(parameter WIDTH = 16) (
    input  wire [2:0]       opcode,
    input  wire [WIDTH-1:0] a,
    input  wire [WIDTH-1:0] b,
    output reg  [WIDTH-1:0] out
);
    // O sintetizador mapeará isso diretamente para uma LUT4
    always @(*) begin
        case (opcode)
            3'b00: out = a & b;      // AND
            3'b01: out = a | b;      // OR
            3'b10: out = a ^ b;      // XOR
            3'b11: out = ~(a ^ b);   // XNOR (XOR invertido - MSB atua como inversor aqui)
        endcase
    end
endmodule
