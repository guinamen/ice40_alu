// =============================================================================
// Unidade Lógica Parametrizável
// =============================================================================
// Realiza operações lógicas bit a bit: AND, OR, XOR e suas inversões
// (NAND, NOR, XNOR, NOT)
// =============================================================================

module unit_logic #(
    parameter WIDTH = 8  // Largura dos operandos em bits
) (
    // Seletores de operação (exatamente um deve estar ativo)
    input  wire c_and,   // Seleciona operação AND
    input  wire c_or,    // Seleciona operação OR
    input  wire c_xor,   // Seleciona operação XOR
    
    // Modificador de inversão
    input  wire c_inv,   // 1 = inverte resultado (NAND/NOR/XNOR/NOT)
    
    // Operandos
    input  wire [WIDTH-1:0] a,
    input  wire [WIDTH-1:0] b,
    
    // Resultado
    output wire [WIDTH-1:0] c
);

    // -------------------------------------------------------------------------
    // Sinais Internos
    // -------------------------------------------------------------------------
    wire [WIDTH-1:0] resultado_base;
    wire [WIDTH-1:0] mascara_and;
    wire [WIDTH-1:0] mascara_or;
    wire [WIDTH-1:0] mascara_xor;
    wire [WIDTH-1:0] mascara_inv;

    // -------------------------------------------------------------------------
    // Geração de Máscaras
    // -------------------------------------------------------------------------
    // Replica o sinal de controle para todos os bits
    assign mascara_and = {WIDTH{c_and}};
    assign mascara_or  = {WIDTH{c_or}};
    assign mascara_xor = {WIDTH{c_xor}};
    assign mascara_inv = {WIDTH{c_inv}};

    // -------------------------------------------------------------------------
    // Multiplexação da Operação Base
    // -------------------------------------------------------------------------
    // Seleciona a operação desejada através de OR de resultados mascarados
    // Se nenhum controle estiver ativo, resultado_base = 0
    assign resultado_base = (mascara_and & (a & b)) |
                           (mascara_or  & (a | b)) |
                           (mascara_xor & (a ^ b));

    // -------------------------------------------------------------------------
    // Inversão Condicional
    // -------------------------------------------------------------------------
    // Aplica XOR para inverter condicionalmente:
    //   - Se c_inv = 0: c = resultado_base ^ 0 = resultado_base
    //   - Se c_inv = 1: c = resultado_base ^ 1 = ~resultado_base
    assign c = resultado_base ^ mascara_inv;

endmodule

// =============================================================================
// Tabela de Operações
// =============================================================================
// | c_and | c_or | c_xor | c_inv | Operação | Resultado |
// |-------|------|-------|-------|----------|-----------|
// |   1   |  0   |   0   |   0   |   AND    |   a & b   |
// |   0   |  1   |   0   |   0   |   OR     |   a | b   |
// |   0   |  0   |   1   |   0   |   XOR    |   a ^ b   |
// |   1   |  0   |   0   |   1   |   NAND   |  ~(a & b) |
// |   0   |  1   |   0   |   1   |   NOR    |  ~(a | b) |
// |   0   |  0   |   1   |   1   |   XNOR   |  ~(a ^ b) |
// |   0   |  0   |   0   |   1   |   NOT    |    ~0     |
// =============================================================================
