`timescale 1ns / 1ps

module adder_tester #(
    parameter integer WIDTH = 32,
    parameter integer BLOCK = 4,
    parameter integer ID    = 0
)(
    input  wire clk,
    output reg  test_done,
    output reg  test_passed
);

    // =========================================================================
    // CHECAGEM DE PARÂMETROS
    // =========================================================================
    initial begin
        if (WIDTH % BLOCK != 0) begin
          $error("[ID %0d] FATAL: WIDTH (%0d) deve ser divisível por BLOCK (%0d).", ID, WIDTH, BLOCK);
            $finish;
        end
    end

    // =========================================================================
    // SINAIS
    // =========================================================================
    reg              v_in;
    reg  [WIDTH-1:0] a, b;
    reg              cin;
    wire [WIDTH-1:0] sum;
    wire             v_out;

    // Variáveis estatísticas (declaradas fora para evitar warning de static initialization)
    integer errors;
    integer checked;

    // Instancia o DUT
    pipelined_adder_core #(
        .WIDTH(WIDTH),
        .BLOCK(BLOCK)
    ) dut (
        .clk(clk), .v_in(v_in), .a(a), .b(b), .cin(cin),
        .sum(sum), .v_out(v_out)
    );

    // =========================================================================
    // SCOREBOARD (CORRIGIDO PARA IVEILOG)
    // =========================================================================
    // Em vez de struct, usamos uma fila de vetores lógicos simples
    // O Icarus Verilog lida bem com 'reg [W:0] queue [$]'
    reg [WIDTH-1:0] expected_queue[$];

    always @(posedge clk) begin
        if (v_out) begin
            reg [WIDTH-1:0] expected_val;

            if (expected_queue.size() == 0) begin
                $error("[ID %0d] FALHA: v_out ativo sem requisição pendente.", ID);
                errors = errors + 1;
            end else begin
                expected_val = expected_queue.pop_front();
                checked = checked + 1;

                if (sum !== expected_val) begin
                    errors = errors + 1;
                    $display("[ID %0d] ERRO: Exp: %h | Obtido: %h | DiffMask: %h",
                             ID, expected_val, sum, (sum ^ expected_val));
                end
            end
        end
    end

    // =========================================================================
    // TASKS
    // =========================================================================
    task drive;
        input [WIDTH-1:0] in_a;
        input [WIDTH-1:0] in_b;
        input             in_cin;
        begin
            a <= in_a;
            b <= in_b;
            cin <= in_cin;
            v_in <= 1'b1;

            // Push na fila (cálculo comportamental simples)
            expected_queue.push_back(in_a + in_b + in_cin);

            @(posedge clk);
        end
    endtask

    task drive_bubble;
        begin
            v_in <= 0;
            a <= 'x; b <= 'x; cin <= 'x;
            @(posedge clk);
        end
    endtask

    // =========================================================================
    // SEQUÊNCIA DE TESTE
    // =========================================================================
    // Variáveis locais para loops
    integer k;
    reg [WIDTH-1:0] val_bound;

    initial begin
        // Inicialização explícita de variáveis
        errors = 0;
        checked = 0;
        test_done = 0;
        test_passed = 0;
        v_in = 0;

        // Aguarda estabilização
        repeat(10) @(posedge clk);

        $display("[ID %0d] Iniciando testes: WIDTH=%0d, BLOCK=%0d", ID, WIDTH, BLOCK);

        // 1. Corner Cases
        drive(0, 0, 0);
        drive({WIDTH{1'b1}}, 0, 1);
        drive({WIDTH{1'b1}}, 1, 0);

        // 2. Teste de Fronteiras
        for (k = BLOCK; k < WIDTH; k = k + BLOCK) begin
            // Shift trick para evitar warning de largura
            val_bound = 1;
            val_bound = (val_bound << k) - 1;
            drive(val_bound, 1, 0);
        end

        // 3. Aleatório Massivo
        repeat(2000) begin
            drive($urandom, $urandom, $urandom % 2);
        end

        // 4. Esvaziar Pipeline
        drive_bubble();
        v_in = 0;
        repeat(20) @(posedge clk);

        // Reportar
        if (errors == 0 && expected_queue.size() == 0) begin
            $display("[ID %0d] SUCESSO. Vetores testados: %0d", ID, checked);
            test_passed = 1;
        end else begin
            $display("[ID %0d] FALHA. Erros: %0d, Fila Restante: %0d", ID, errors, expected_queue.size());
            test_passed = 0;
        end

        test_done = 1;
    end

endmodule
