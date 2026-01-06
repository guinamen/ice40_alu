module high_speed_acc_v3 (
    input wire clk,
    input wire reset,
    input wire [31:0] A,
    input wire [31:0] B,
    output reg [31:0] final_acc
);

    // 1. Registradores de Entrada (Força o uso de IOBs)
    reg [31:0] Ar, Br;
    always @(posedge clk) begin
        Ar <= A;
        Br <= B;
    end

    // 2. Núcleo do Acumulador CSA (Feedback Loop)
    // Este trecho não usa carry chain, apenas LUTs simples.
    reg [31:0] acc_s, acc_c;
    wire [31:0] s1, c1, ns, nc;

    assign s1 = Ar ^ Br ^ acc_s;
    assign c1 = (Ar & Br) | (Ar & acc_s) | (Br & acc_s);
    assign ns = s1 ^ {c1[30:0], 1'b0} ^ acc_c;
    assign nc = (s1 & {c1[30:0], 1'b0}) | (s1 & acc_c) | ({c1[30:0], 1'b0} & acc_c);

    always @(posedge clk) begin
        if (reset) begin
            acc_s <= 0; acc_c <= 0;
        end else begin
            acc_s <= ns;
            acc_c <= {nc[30:0], 1'b0};
        end
    end

    // 3. Somador Final Pipelined (8 estágios de 4 bits)
    // Estrutura de registro para carregar os pedaços (chunks)
    reg [31:0] s_pipe [0:6];
    reg [31:0] c_pipe [0:6];
    reg [7:0]  cry; // Carries entre os estágios
    reg [31:0] res_pipe;

    integer i;
    always @(posedge clk) begin
        // Estágio 1: Bits 0-3
        {cry[0], res_pipe[3:0]} <= acc_s[3:0] + acc_c[3:0];
        s_pipe[0] <= acc_s; c_pipe[0] <= acc_c;

        // Estágios 2 a 7: Blocos intermediários
        for (i = 1; i < 7; i = i + 1) begin
            {cry[i], res_pipe[i*4 +: 4]} <= s_pipe[i-1][i*4 +: 4] + c_pipe[i-1][i*4 +: 4] + cry[i-1];
            s_pipe[i] <= s_pipe[i-1]; 
            c_pipe[i] <= c_pipe[i-1];
        end

        // Estágio 8: Bits 28-31
        final_acc[27:0] <= res_pipe[27:0];
        final_acc[31:28] <= s_pipe[6][31:28] + c_pipe[6][31:28] + cry[6];
    end

endmodule
