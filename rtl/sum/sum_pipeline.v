`timescale 1ns / 1ps

// =============================================================================
// MÓDULOS AUXILIARES (RCA, CS_BLOCK, PREFIX_TREE)
// Permanecem os mesmos para garantir a lógica de soma
// =============================================================================

module rca #(parameter integer WIDTH = 4) (
    input  wire [WIDTH-1:0] a, b,
    input  wire             cin,
    output wire [WIDTH-1:0] sum,
    output wire             cout
);
    assign {cout, sum} = a + b + {{(WIDTH-1){1'b0}}, cin};
endmodule

module cs_block #(parameter integer WIDTH = 4) (
    input  wire [WIDTH-1:0] a, b,
    output wire [WIDTH-1:0] sum0, sum1,
    output wire             G, P,
    output wire             c0, c1
);
    rca #(WIDTH) rca0 (.a(a), .b(b), .cin(1'b0), .sum(sum0), .cout(c0));
    rca #(WIDTH) rca1 (.a(a), .b(b), .cin(1'b1), .sum(sum1), .cout(c1));
    assign G = c0;
    assign P = c1 ^ c0;
endmodule

module parallel_prefix_tree #(parameter integer N = 8) (
    input  wire [N-1:0] G_in, P_in,
    input  wire         cin,
    output wire [N-1:0] C_out
);
    localparam DEPTH = $clog2(N);
    wire [N-1:0] arvore_g [0:DEPTH];
    wire [N-1:0] arvore_p [0:DEPTH];

    assign arvore_g[0] = G_in;
    assign arvore_p[0] = P_in;

    genvar nivel, bit_idx, k;
    generate
        for (nivel = 0; nivel < DEPTH; nivel = nivel + 1) begin : NIVEL
            localparam integer DIST = 2**nivel;
            for (bit_idx = 0; bit_idx < N; bit_idx = bit_idx + 1) begin : BIT
                if (bit_idx < DIST) begin
                    assign arvore_g[nivel+1][bit_idx] = arvore_g[nivel][bit_idx];
                    assign arvore_p[nivel+1][bit_idx] = arvore_p[nivel][bit_idx];
                end else begin
                    assign arvore_g[nivel+1][bit_idx] = arvore_g[nivel][bit_idx] | (arvore_p[nivel][bit_idx] & arvore_g[nivel][bit_idx-DIST]);
                    assign arvore_p[nivel+1][bit_idx] = arvore_p[nivel][bit_idx] & arvore_p[nivel][bit_idx-DIST];
                end
            end
        end
        for (k = 0; k < N; k = k + 1) begin : C_FINAL
            assign C_out[k] = arvore_g[DEPTH][k] | (arvore_p[DEPTH][k] & cin);
        end
    endgenerate
endmodule

// =============================================================================
// MÓDULO PRINCIPAL: SEM RESET (OTIMIZADO PARA iCE40)
// =============================================================================
module pipelined_adder #(
    parameter integer WIDTH = 32,
    parameter integer BLOCK = 8
)(
    input  wire             clk,
    input  wire             v_in,
    input  wire [WIDTH-1:0] a,
    input  wire [WIDTH-1:0] b,
    input  wire             cin,
    output reg  [WIDTH-1:0] sum,
    output reg              v_out,
    output reg              cout
);
    localparam integer NUM_BLOCOS = WIDTH / BLOCK;

    // Inicialização para Power-On (Suportado por iCE40/Yosys)
    initial v_out = 0;

    // --- ESTÁGIO 1 ---
    reg [WIDTH-1:0] estagio1_a, estagio1_b;
    reg             estagio1_cin;
    reg             v_in_2 = 0;

    always @(posedge clk) begin
        if (v_in) begin
            estagio1_a   <= a;
            estagio1_b   <= b;
            estagio1_cin <= cin;
        end else begin
            estagio1_a   <= 0;
            estagio1_b   <= 0;
            estagio1_cin <= 0;

        end
        v_in_2 <= v_in;
    end

    // --- ESTÁGIO 2 ---
    wire [WIDTH-1:0] wire_s0, wire_s1;
    wire [NUM_BLOCOS-1:0] wire_G, wire_P;

    genvar bi;
    generate
        for (bi = 0; bi < NUM_BLOCOS; bi = bi + 1) begin : BLOCOS
            cs_block #(BLOCK) cb (
                .a(estagio1_a[bi*BLOCK +: BLOCK]), .b(estagio1_b[bi*BLOCK +: BLOCK]),
                .sum0(wire_s0[bi*BLOCK +: BLOCK]), .sum1(wire_s1[bi*BLOCK +: BLOCK]),
                .G(wire_G[bi]), .P(wire_P[bi]), .c0(), .c1()
            );
        end
    endgenerate

    reg [WIDTH-1:0]      est2_s0, est2_s1;
    reg [NUM_BLOCOS-1:0] est2_G, est2_P;
    reg                  est2_cin, v_in_3 = 0;

    always @(posedge clk) begin
        if (v_in_2) begin
            est2_s0  <= wire_s0;
            est2_s1  <= wire_s1;
            est2_G   <= wire_G;
            est2_P   <= wire_P;
            est2_cin <= estagio1_cin;
        end
        v_in_3 <= v_in_2;
    end

    // --- ESTÁGIO 3 ---
    wire [NUM_BLOCOS-1:0] wire_c_out;
    parallel_prefix_tree #(NUM_BLOCOS) ppt (
        .G_in(est2_G), .P_in(est2_P), .cin(est2_cin), .C_out(wire_c_out)
    );

    reg [WIDTH-1:0]      est3_s0, est3_s1;
    reg [NUM_BLOCOS-1:0] est3_sel;
    reg                  est3_cout_final, v_in_4 = 0;

    always @(posedge clk) begin
        if (v_in_3) begin
            est3_s0         <= est2_s0;
            est3_s1         <= est2_s1;
            est3_sel        <= {wire_c_out[NUM_BLOCOS-2:0], est2_cin};
            est3_cout_final <= wire_c_out[NUM_BLOCOS-1];
        end
        v_in_4 <= v_in_3;
    end

    // --- ESTÁGIO 4 ---
    integer i;
    always @(posedge clk) begin
        if (v_in_4) begin
            cout <= est3_cout_final;
            for (i = 0; i < NUM_BLOCOS; i = i + 1) begin
                sum[i*BLOCK +: BLOCK] <= est3_sel[i] ?
                                         est3_s1[i*BLOCK +: BLOCK] :
                                         est3_s0[i*BLOCK +: BLOCK];
            end
        end
        v_out <= v_in_4;
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
