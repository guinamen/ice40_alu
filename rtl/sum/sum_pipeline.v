`timescale 1ns / 1ps

// =============================================================================
// Somador Carry-Select em Pipeline de 4 Estágios
// =============================================================================
// Arquitetura otimizada para alta frequência usando paralelização e pipelining
//
// Pipeline:
//   Estágio 1: Captura de entrada (Input Register)
//   Estágio 2: Cálculo dos blocos (Soma com Cin=0 e Cin=1, Generate, Propagate)
//   Estágio 3: Árvore de prefixo paralela (Cálculo dos carries intermediários)
//   Estágio 4: Seleção final via multiplexação e registrador de saída
//
// Latência: 4 ciclos de clock
// Throughput: 1 operação por ciclo (após preenchimento do pipeline)
// =============================================================================


// =============================================================================
// MÓDULOS AUXILIARES
// =============================================================================

// -----------------------------------------------------------------------------
// Ripple Carry Adder (RCA)
// -----------------------------------------------------------------------------
// Somador simples com propagação de carry
// Usado para calcular somas locais dentro de cada bloco
// -----------------------------------------------------------------------------
module rca #(
    parameter integer WIDTH = 4  // Largura do bloco
)(
    input  wire [WIDTH-1:0] a,     // Operando A
    input  wire [WIDTH-1:0] b,     // Operando B
    input  wire             cin,   // Carry de entrada
    output wire [WIDTH-1:0] sum,   // Resultado da soma
    output wire             cout   // Carry de saída
);
    // Soma completa em uma única atribuição
    assign {cout, sum} = a + b + {{(WIDTH-1){1'b0}}, cin};
endmodule


// -----------------------------------------------------------------------------
// Bloco Carry-Select
// -----------------------------------------------------------------------------
// Calcula duas somas em paralelo (assumindo Cin=0 e Cin=1)
// Gera os sinais Generate (G) e Propagate (P) para a árvore de prefixo
// -----------------------------------------------------------------------------
module cs_block #(
    parameter integer WIDTH = 4  // Largura do bloco
)(
    input  wire [WIDTH-1:0] a,      // Operando A
    input  wire [WIDTH-1:0] b,      // Operando B

    output wire [WIDTH-1:0] sum0,   // Soma assumindo Cin=0
    output wire [WIDTH-1:0] sum1,   // Soma assumindo Cin=1
    output wire             c0,     // Carry out quando Cin=0
    output wire             c1,     // Carry out quando Cin=1
    output wire             G,      // Generate: este bloco gera carry
    output wire             P       // Propagate: este bloco propaga carry
);
    // Instanciação dos somadores paralelos
    rca #(WIDTH) rca_cin0 (
        .a   (a),
        .b   (b),
        .cin (1'b0),
        .sum (sum0),
        .cout(c0)
    );

    rca #(WIDTH) rca_cin1 (
        .a   (a),
        .b   (b),
        .cin (1'b1),
        .sum (sum1),
        .cout(c1)
    );

    // Sinais Generate e Propagate
    assign G = c0;           // Gera carry quando Cin=0
    assign P = c1 ^ c0;      // Propaga carry se houver diferença entre c0 e c1
endmodule


// -----------------------------------------------------------------------------
// Árvore de Prefixo Paralela (Parallel Prefix Tree)
// -----------------------------------------------------------------------------
// Calcula os carries de saída de todos os blocos em tempo logarítmico
// Implementa o algoritmo de Kogge-Stone para máxima paralelização
// -----------------------------------------------------------------------------
module parallel_prefix_tree #(
    parameter integer N = 8  // Número de blocos
)(
    input  wire [N-1:0] G_in,    // Sinais Generate dos blocos
    input  wire [N-1:0] P_in,    // Sinais Propagate dos blocos
    input  wire         cin,     // Carry de entrada global
    output wire [N-1:0] C_out    // Carries de saída de cada bloco
);
    // Profundidade da árvore (log2 de N)
    localparam DEPTH = $clog2(N);

    // Arrays bidimensionais para armazenar G e P em cada nível da árvore
    wire [N-1:0] arvore_g [DEPTH:0];  // Generate em cada estágio
    wire [N-1:0] arvore_p [DEPTH:0];  // Propagate em cada estágio

    // Nível 0: Entrada direta dos sinais dos blocos
    assign arvore_g[0] = G_in;
    assign arvore_p[0] = P_in;

    // Construção da árvore de prefixo
    genvar nivel, bit;
    generate
        // Para cada nível da árvore
        for (nivel = 0; nivel < DEPTH; nivel = nivel + 1) begin : NIVEL_ARVORE
            localparam integer DISTANCIA = 2**nivel;  // Distância de combinação neste nível

            // Para cada bit/bloco
            for (bit = 0; bit < N; bit = bit + 1) begin : BLOCO_BIT
                if (bit < DISTANCIA) begin
                    // Bits iniciais: apenas propaga do nível anterior
                    assign arvore_g[nivel+1][bit] = arvore_g[nivel][bit];
                    assign arvore_p[nivel+1][bit] = arvore_p[nivel][bit];
                end else begin
                    // Combinação com vizinho anterior na distância atual
                    // G_novo = G_atual OU (P_atual E G_anterior)
                    // P_novo = P_atual E P_anterior
                    assign arvore_g[nivel+1][bit] = arvore_g[nivel][bit] |
                                                    (arvore_p[nivel][bit] & arvore_g[nivel][bit-DISTANCIA]);
                    assign arvore_p[nivel+1][bit] = arvore_p[nivel][bit] & arvore_p[nivel][bit-DISTANCIA];
                end
            end
        end
    endgenerate

    // Cálculo final dos carries de saída
    // C_out[k] = G[k] OU (P[k] E Cin)
    genvar k;
    generate
        for (k = 0; k < N; k = k + 1) begin : CARRY_FINAL
            assign C_out[k] = arvore_g[DEPTH][k] | (arvore_p[DEPTH][k] & cin);
        end
    endgenerate
endmodule


// =============================================================================
// MÓDULO PRINCIPAL: SOMADOR PIPELINE
// =============================================================================
module pipelined_adder #(
    parameter integer WIDTH = 32,  // Largura total do somador (bits)
    parameter integer BLOCK = 8    // Largura de cada bloco carry-select
)(
    input  wire             clk,   // Clock do sistema
    input  wire             rst,   // Reset síncrono ativo em alto

    // Entradas (registradas no Estágio 1)
    input  wire [WIDTH-1:0] a,     // Operando A
    input  wire [WIDTH-1:0] b,     // Operando B
    input  wire             cin,   // Carry de entrada

    // Saídas (disponíveis no Estágio 4)
    output reg  [WIDTH-1:0] sum,   // Resultado da soma
    output reg              cout   // Carry de saída
);
    // Número de blocos carry-select
    localparam integer NUM_BLOCOS = WIDTH / BLOCK;


    // =========================================================================
    // ESTÁGIO 1: REGISTRADORES DE ENTRADA
    // =========================================================================
    // Captura as entradas e as sincroniza com o pipeline
    // =========================================================================
    reg [WIDTH-1:0] estagio1_a;
    reg [WIDTH-1:0] estagio1_b;
    reg             estagio1_cin;

    always @(posedge clk) begin
        if (rst) begin
            estagio1_a   <= {WIDTH{1'b0}};
            estagio1_b   <= {WIDTH{1'b0}};
            estagio1_cin <= 1'b0;
        end else begin
            estagio1_a   <= a;
            estagio1_b   <= b;
            estagio1_cin <= cin;
        end
    end


    // =========================================================================
    // ESTÁGIO 2: CÁLCULO DOS BLOCOS CARRY-SELECT
    // =========================================================================
    // Cada bloco calcula duas somas (Cin=0 e Cin=1) e gera sinais G/P
    // Operação puramente combinacional, seguida de registro
    // =========================================================================

    // Sinais combinacionais dos blocos
    wire [WIDTH-1:0]      wire_soma_cin0;    // Todas as somas com Cin=0
    wire [WIDTH-1:0]      wire_soma_cin1;    // Todas as somas com Cin=1
    wire [NUM_BLOCOS-1:0] wire_generate;     // Sinais Generate de cada bloco
    wire [NUM_BLOCOS-1:0] wire_propagate;    // Sinais Propagate de cada bloco
    wire [NUM_BLOCOS-1:0] wire_carry0;       // Carries com Cin=0 (não usado no pipeline)
    wire [NUM_BLOCOS-1:0] wire_carry1;       // Carries com Cin=1 (não usado no pipeline)

    // Geração dos blocos carry-select
    genvar bloco_idx;
    generate
        for (bloco_idx = 0; bloco_idx < NUM_BLOCOS; bloco_idx = bloco_idx + 1) begin : BLOCOS_CS
            cs_block #(
                .WIDTH(BLOCK)
            ) bloco_cs (
                .a   (estagio1_a[bloco_idx*BLOCK +: BLOCK]),
                .b   (estagio1_b[bloco_idx*BLOCK +: BLOCK]),
                .sum0(wire_soma_cin0[bloco_idx*BLOCK +: BLOCK]),
                .sum1(wire_soma_cin1[bloco_idx*BLOCK +: BLOCK]),
                .c0  (wire_carry0[bloco_idx]),
                .c1  (wire_carry1[bloco_idx]),
                .G   (wire_generate[bloco_idx]),
                .P   (wire_propagate[bloco_idx])
            );
        end
    endgenerate

    // Registradores do Estágio 2
    reg [WIDTH-1:0]      estagio2_soma_cin0;
    reg [WIDTH-1:0]      estagio2_soma_cin1;
    reg [NUM_BLOCOS-1:0] estagio2_generate;
    reg [NUM_BLOCOS-1:0] estagio2_propagate;
    reg                  estagio2_cin;

    always @(posedge clk) begin
        if (rst) begin
            estagio2_soma_cin0  <= {WIDTH{1'b0}};
            estagio2_soma_cin1  <= {WIDTH{1'b0}};
            estagio2_generate   <= {NUM_BLOCOS{1'b0}};
            estagio2_propagate  <= {NUM_BLOCOS{1'b0}};
            estagio2_cin        <= 1'b0;
        end else begin
            estagio2_soma_cin0  <= wire_soma_cin0;
            estagio2_soma_cin1  <= wire_soma_cin1;
            estagio2_generate   <= wire_generate;
            estagio2_propagate  <= wire_propagate;
            estagio2_cin        <= estagio1_cin;  // Propaga Cin para próximo estágio
        end
    end


    // =========================================================================
    // ESTÁGIO 3: ÁRVORE DE PREFIXO (CÁLCULO DOS CARRIES)
    // =========================================================================
    // Usa árvore de prefixo paralela para calcular carries em tempo O(log N)
    // As somas calculadas no estágio anterior são propagadas (pipeline balancing)
    // =========================================================================

    // Sinais combinacionais da árvore
    wire [NUM_BLOCOS-1:0] wire_carries_blocos;

    parallel_prefix_tree #(
        .N(NUM_BLOCOS)
    ) arvore_carries (
        .G_in (estagio2_generate),
        .P_in (estagio2_propagate),
        .cin  (estagio2_cin),
        .C_out(wire_carries_blocos)
    );

    // Registradores do Estágio 3
    reg [WIDTH-1:0]      estagio3_soma_cin0;
    reg [WIDTH-1:0]      estagio3_soma_cin1;
    reg [NUM_BLOCOS-1:0] estagio3_seletor;      // Máscara de seleção para MUX
    reg                  estagio3_carry_final;  // Carry de saída global

    always @(posedge clk) begin
        if (rst) begin
            estagio3_soma_cin0   <= {WIDTH{1'b0}};
            estagio3_soma_cin1   <= {WIDTH{1'b0}};
            estagio3_seletor     <= {NUM_BLOCOS{1'b0}};
            estagio3_carry_final <= 1'b0;
        end else begin
            // Pipeline balancing: propaga as somas calculadas anteriormente
            estagio3_soma_cin0 <= estagio2_soma_cin0;
            estagio3_soma_cin1 <= estagio2_soma_cin1;

            // Construção do seletor para cada bloco:
            // - Bloco 0: usa Cin original
            // - Bloco K (K>0): usa Carry out do bloco K-1
            estagio3_seletor[0]              <= estagio2_cin;
            estagio3_seletor[NUM_BLOCOS-1:1] <= wire_carries_blocos[NUM_BLOCOS-2:0];

            // Carry de saída global é o carry do último bloco
            estagio3_carry_final <= wire_carries_blocos[NUM_BLOCOS-1];
        end
    end


    // =========================================================================
    // ESTÁGIO 4: SELEÇÃO FINAL E REGISTRADOR DE SAÍDA
    // =========================================================================
    // Multiplexação entre soma_cin0 e soma_cin1 baseada nos carries calculados
    // Resultado final é registrado para saída
    // =========================================================================
    integer idx_bloco;

    always @(posedge clk) begin
        if (rst) begin
            sum  <= {WIDTH{1'b0}};
            cout <= 1'b0;
        end else begin
            // Carry de saída
            cout <= estagio3_carry_final;

            // Multiplexação bloco a bloco
            // Se seletor[k]=1, usa soma_cin1; caso contrário, usa soma_cin0
            for (idx_bloco = 0; idx_bloco < NUM_BLOCOS; idx_bloco = idx_bloco + 1) begin
                if (estagio3_seletor[idx_bloco]) begin
                    sum[idx_bloco*BLOCK +: BLOCK] <= estagio3_soma_cin1[idx_bloco*BLOCK +: BLOCK];
                end else begin
                    sum[idx_bloco*BLOCK +: BLOCK] <= estagio3_soma_cin0[idx_bloco*BLOCK +: BLOCK];
                end
            end
        end
    end

endmodule


// =============================================================================
// NOTAS DE IMPLEMENTAÇÃO
// =============================================================================
// 1. Latência: 4 ciclos de clock do início ao resultado
// 2. Throughput: 1 operação por ciclo após preenchimento do pipeline
// 3. Área: O(N) onde N é o número de bits (WIDTH)
// 4. Tempo crítico: Dominado pela árvore de prefixo no Estágio 3
// 5. Parâmetros recomendados: BLOCK entre 4 e 16 para melhor balanço área/tempo
// =============================================================================
