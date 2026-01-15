`timescale 1ns / 1ps

module tb_multi_config;

    // Geração de Clock Global
    reg clk = 0;
    always #5 clk = ~clk; // 100MHz

    // Sinais de controle de fim de teste
    wire [3:0] done;
    wire [3:0] passed;

    // =========================================================================
    // CENÁRIO 1: Pequeno e Granular (Stress alto na Prefix Tree)
    // WIDTH=16, BLOCK=2 -> Gera 8 blocos. A árvore de prefixo terá profundidade 3.
    // Testa se o overhead da lógica de prefixo funciona em blocos pequenos.
    // =========================================================================
    adder_tester #(.WIDTH(16), .BLOCK(2), .ID(1)) t1 (
        .clk(clk), .test_done(done[0]), .test_passed(passed[0])
    );

    // =========================================================================
    // CENÁRIO 2: Padrão (Balanceado)
    // WIDTH=32, BLOCK=4 -> Gera 8 blocos.
    // Configuração típica de uso.
    // =========================================================================
    adder_tester #(.WIDTH(32), .BLOCK(4), .ID(2)) t2 (
        .clk(clk), .test_done(done[1]), .test_passed(passed[1])
    );

    // =========================================================================
    // CENÁRIO 3: Blocos Largos (Stress no Carry Select Local)
    // WIDTH=32, BLOCK=8 -> Gera 4 blocos.
    // A árvore é rasa (profundidade 2), mas os RCAs internos (rca_0/1) são maiores.
    // Testa se a lógica interna do rca_1 otimizado aguenta cadeias mais longas.
    // =========================================================================
    adder_tester #(.WIDTH(32), .BLOCK(8), .ID(3)) t3 (
        .clk(clk), .test_done(done[2]), .test_passed(passed[2])
    );

    // =========================================================================
    // CENÁRIO 4: Large Scale (64-bit Adder)
    // WIDTH=64, BLOCK=4 -> Gera 16 blocos. Árvore de profundidade 4.
    // Testa propagação de carry extremamente longa e timing lógico.
    // =========================================================================
    adder_tester #(.WIDTH(64), .BLOCK(4), .ID(4)) t4 (
        .clk(clk), .test_done(done[3]), .test_passed(passed[3])
    );

    // =========================================================================
    // MONITOR DE CONCLUSÃO
    // =========================================================================
    initial begin
        $display("=== INICIANDO SIMULAÇÃO MULTI-CONFIGURAÇÃO ===");

        // Espera todos terminarem (AND reduction)
        wait(done == 4'b1111);

        $display("\n=== RELATÓRIO FINAL ===");
        if (passed == 4'b1111) begin
            $display("STATUS GLOBAL: PASSED");
            $display("Todas as 4 configurações passaram nos testes rigorosos.");
        end else begin
            $display("STATUS GLOBAL: FAILED");
            $display("Configurações que falharam: %b (0=Fail, 1=Pass)", passed);
        end
        $finish;
    end

endmodule
