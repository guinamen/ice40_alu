
module alu_slice4_nondep (
    input         clk,
    input         v_in,     // Validade das entradas

    input  [3:0]  a_in,     // Operando A
    input  [3:0]  b_in,     // Operando B

    // Sinais de controle (assume apenas um ativo por ciclo)
    input         do_and,
    input         do_or,
    input         do_xor,
    input         do_not,
    input         do_pass,

    output [3:0]  result,   // Resultado registrado
    output        v_out     // Validade do resultado
);

    // ------------------------------------------------------------------
    // Registradores de entrada
    // Atualizados apenas quando v_in = 1 (clock enable implícito)
    // ------------------------------------------------------------------
    reg [3:0] a_r;
    reg [3:0] b_r;

    // Pipeline de validade
    reg v_pipe;

    always @(posedge clk) begin
        if (v_in) begin
            a_r    <= a_in;
            b_r    <= b_in;
            v_pipe <= 1'b1;
        end else begin
            // NÃO zera registradores (otimização #1)
            v_pipe <= 1'b0;
        end
    end

    // ------------------------------------------------------------------
    // Lógica combinacional da ALU
    // Calculada sempre, mas só usada quando v_pipe = 1
    // ------------------------------------------------------------------
    wire [3:0] and_res  = a_r & b_r;
    wire [3:0] or_res   = a_r | b_r;
    wire [3:0] xor_res  = a_r ^ b_r;
    wire [3:0] not_res  = ~a_r;
    wire [3:0] pass_res = a_r;

    // ------------------------------------------------------------------
    // Seleção da operação
    // Implementação por mascaramento lógico
    // ------------------------------------------------------------------
    wire [3:0] result_c =
          ({4{do_and }} & and_res )
        | ({4{do_or  }} & or_res  )
        | ({4{do_xor }} & xor_res )
        | ({4{do_not }} & not_res )
        | ({4{do_pass}} & pass_res);

    // ------------------------------------------------------------------
    // Registro de saída
    // Clock enable implícito preservado (otimização #2)
    // ------------------------------------------------------------------
    reg [3:0] result_r;
    reg       v_out_r;

    always @(posedge clk) begin
        if (v_pipe) begin
            result_r <= result_c;
            v_out_r  <= 1'b1;
        end else begin
            // Mantém valor antigo; v_out indica invalidade
            v_out_r  <= 1'b0;
        end
    end

    // ------------------------------------------------------------------
    // Saídas
    // ------------------------------------------------------------------
    assign result = result_r;
    assign v_out  = v_out_r;

endmodule
