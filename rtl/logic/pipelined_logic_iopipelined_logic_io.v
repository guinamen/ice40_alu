// ---------------------------------------------------------
// Módulo de IO com Pipeline Corrigido
// ---------------------------------------------------------
module pipelined_logic_io #(
    parameter integer WIDTH = 32,
    parameter integer BLOCK = 16
)(
    input  wire             clk,
    input  wire             v_in,

    // Novo Controle Unificado (2 bits)
    input  wire [1:0]       opcode,

    input  wire [WIDTH-1:0] a,
    input  wire [WIDTH-1:0] b,

    output wire [WIDTH-1:0] out,
    output wire             v_out
);

    // -----------------------------
    // INPUT IOB (Registradores de Entrada)
    // -----------------------------
    (* IOB = "true" *) reg [WIDTH-1:0] a_iob, b_iob;
    (* IOB = "true" *) reg             v_iob;

    // O Opcode também precisa ir para o IOB para alinhar o timing
    (* IOB = "true" *) reg [1:0] opcode_iob;

    always @(posedge clk) begin
        a_iob      <= a;
        b_iob      <= b;
        v_iob      <= v_in;
        opcode_iob <= opcode; // Pipeline do controle
    end

    // -----------------------------
    // CORE (Geração de Blocos)
    // -----------------------------
    wire [WIDTH-1:0] res_core;

    genvar i;
    generate
        for (i = 0; i < (WIDTH / BLOCK); i = i + 1) begin : gen_blocks
            // Instancia a unidade otimizada
            unit_logic_opt #(
                .WIDTH(BLOCK)
            ) u_logic (
                .opcode(opcode_iob),       // Controle comum a todos
                .a     (a_iob[i*BLOCK +: BLOCK]),
                .b     (b_iob[i*BLOCK +: BLOCK]),
                .out   (res_core[i*BLOCK +: BLOCK])
            );
        end
    endgenerate

    // -----------------------------
    // OUTPUT IOB (Registradores de Saída)
    // -----------------------------
    (* IOB = "true" *) reg [WIDTH-1:0] out_iob;
    (* IOB = "true" *) reg             v_out_iob;

    always @(posedge clk) begin
        out_iob   <= res_core;
        v_out_iob <= v_iob;
    end

    assign out   = out_iob;
    assign v_out = v_out_iob;

endmodule
