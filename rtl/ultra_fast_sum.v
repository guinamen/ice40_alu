/*
 * Módulo: high_speed_acc_32bit
 * Objetivo: Acumulação A + B + ACC a > 250MHz na iCE40
 * Latência: 10 ciclos (1 entrada + 1 feedback + 8 pipeline)
 * Throughput: 1 operação por ciclo
 */
module high_speed_acc_32bit (
    input wire clk,
    input wire reset,
    input wire [31:0] A,
    input wire [31:0] B,
    output reg [31:0] final_acc
);

    // 1. REGISTRADORES DE ENTRADA (Aproveita os IOBs da iCE40)
    // Reduz drasticamente o atraso entre o pino físico e a lógica interna
    reg [31:0] Ar, Br;
    always @(posedge clk) begin
        Ar <= A;
        Br <= B;
    end

    // 2. NÚCLEO DO ACUMULADOR CARRY-SAVE (CSA)
    // Transforma a soma de 4 números (A, B, acc_s, acc_c) em 2 números.
    // O caminho crítico aqui é de apenas 2 LUTs, sem propagação de carry.
    reg [31:0] acc_s, acc_c;
    wire [31:0] s1, c1, s2, c2;
    wire [31:0] c1_sh, c2_sh;

    // Camada 1: Reduz Ar, Br, acc_s -> s1, c1
    assign s1 = Ar ^ Br ^ acc_s;
    assign c1 = (Ar & Br) | (Ar & acc_s) | (Br & acc_s);
    assign c1_sh = {c1[30:0], 1'b0};

    // Camada 2: Reduz s1, c1_sh, acc_c -> s2, c2
    assign s2 = s1 ^ c1_sh ^ acc_c;
    assign c2 = (s1 & c1_sh) | (s1 & acc_c) | (c1_sh & acc_c);
    assign c2_sh = {c2[30:0], 1'b0};

    always @(posedge clk) begin
        if (reset) begin
            acc_s <= 32'h0;
            acc_c <= 32'h0;
        end else begin
            acc_s <= s2;
            acc_c <= c2_sh;
        end
    end

    // 3. PIPELINE EM FUNIL (8 ESTÁGIOS DE 4 BITS)
    // Cada estágio resolve 4 bits e passa o restante adiante.
    // Isso reduz o congestionamento de fios e o fanout do clock.

    // Definição dos sinais dos estágios
    reg [3:0]  st_res [0:7]; // Somas parciais
    reg [7:0]  st_cry;       // Carries entre blocos
    
    // Registradores "Funnel" para reduzir largura de banda
    reg [27:0] rem_s1, rem_c1;
    reg [23:0] rem_s2, rem_c2;
    reg [19:0] rem_s3, rem_c3;
    reg [15:0] rem_s4, rem_c4;
    reg [11:0] rem_s5, rem_c5;
    reg [7:0]  rem_s6, rem_c6;
    reg [3:0]  rem_s7, rem_c7;

    // Atrasos para alinhar as somas parciais na saída
    reg [3:0] d1_0;
    reg [7:0] d2_0;
    reg [11:0] d3_0;
    reg [15:0] d4_0;
    reg [19:0] d5_0;
    reg [23:0] d6_0;
    reg [27:0] d7_0;

    always @(posedge clk) begin
        // Estágio 1: Bits [3:0]
        {st_cry[0], st_res[0]} <= acc_s[3:0] + acc_c[3:0];
        rem_s1 <= acc_s[31:4]; rem_c1 <= acc_c[31:4];

        // Estágio 2: Bits [7:4]
        {st_cry[1], st_res[1]} <= rem_s1[3:0] + rem_c1[3:0] + st_cry[0];
        rem_s2 <= rem_s1[27:4]; rem_c2 <= rem_c1[27:4];
        d1_0 <= st_res[0];

        // Estágio 3: Bits [11:8]
        {st_cry[2], st_res[2]} <= rem_s2[3:0] + rem_c2[3:0] + st_cry[1];
        rem_s3 <= rem_s2[23:4]; rem_c3 <= rem_c2[23:4];
        d2_0 <= {st_res[1], d1_0};

        // Estágio 4: Bits [15:12]
        {st_cry[3], st_res[3]} <= rem_s3[3:0] + rem_c3[3:0] + st_cry[2];
        rem_s4 <= rem_s3[19:4]; rem_c4 <= rem_c3[19:4];
        d3_0 <= {st_res[2], d2_0};

        // Estágio 5: Bits [19:16]
        {st_cry[4], st_res[4]} <= rem_s4[3:0] + rem_c4[3:0] + st_cry[3];
        rem_s5 <= rem_s4[15:4]; rem_c5 <= rem_c4[15:4];
        d4_0 <= {st_res[3], d3_0};

        // Estágio 6: Bits [23:20]
        {st_cry[5], st_res[5]} <= rem_s5[3:0] + rem_c5[3:0] + st_cry[4];
        rem_s6 <= rem_s5[11:4]; rem_c6 <= rem_c5[11:4];
        d5_0 <= {st_res[4], d4_0};

        // Estágio 7: Bits [27:24]
        {st_cry[6], st_res[6]} <= rem_s6[3:0] + rem_c6[3:0] + st_cry[5];
        rem_s7 <= rem_s6[7:4]; rem_c7 <= rem_c6[7:4];
        d6_0 <= {st_res[5], d5_0};

        // Estágio 8: Bits [31:28]
        // Resultado final é montado aqui
        final_acc[31:28] <= rem_s7[3:0] + rem_c7[3:0] + st_cry[6];
        final_acc[27:0]  <= {st_res[6], d6_0};
    end

endmodule
