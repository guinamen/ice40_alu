/*
 * Wrapper para Isolamento de I/O e Medição de Fmax
 * Este módulo isola a lógica 'Nitro' entre dois estágios de registradores.
 */
module plus_one_top (
    input  wire        clk,
    input  wire [31:0] data_in,
    output reg  [31:0] data_out
);

    // 1. Registradores de Entrada
    // Isola o atraso dos pinos de entrada (Pad -> Fabric)
    reg [31:0] data_in_reg;
    always @(posedge clk) begin
        data_in_reg <= data_in;
    end

    // 2. Instância da Lógica Nitro (Combinacional)
    wire [31:0] w_data_out;
    plus_one nitro_inst (
        .data_in (data_in_reg),
        .w_data_out (w_data_out)
    );

    // 3. Registradores de Saída
    // Isola o atraso dos pinos de saída (Fabric -> Pad)
    always @(posedge clk) begin
        data_out <= w_data_out;
    end

endmodule

// --- Módulo Nitro Integrado ---
module plus_one (
    input  wire [31:0] data_in,
    output wire [31:0] w_data_out
);
    wire [15:0] inc0 = data_in[15:0] + 1'b1;
    wire [15:0] inc1 = data_in[31:16] + 1'b1;
    wire bf0 = &data_in[15:0];

    assign w_data_out[15:0]  = inc0;
    assign w_data_out[31:16] = bf0 ? inc1 : data_in[31:16];
endmodule
