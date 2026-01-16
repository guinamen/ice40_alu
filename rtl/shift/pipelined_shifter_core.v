module pipelined_shifter_core #(
    parameter integer WIDTH = 32, // Experimente mudar para 32, 16, 8
    parameter integer BLOCK = 16   // Tamanho do bloco de otimização
)(
    input  wire             clk,
    input  wire [1:0]       opcode,
    // O tamanho do shamt é calculado automaticamente: Log2(WIDTH)
    input  wire [$clog2(WIDTH)-1:0] shamt, 
    input  wire             v_in,
    input  wire [WIDTH-1:0] din,
    
    output reg  [WIDTH-1:0] dout,
    output reg              v_out
);

    // Função para calcular Log2 (Ceiling)
    function integer clog2;
        input integer value;
        begin
            value = value - 1;
            for (clog2 = 0; value > 0; clog2 = clog2 + 1)
                value = value >> 1;
        end
    endfunction

    localparam integer STAGES = clog2(WIDTH); // Ex: 16->4, 32->5

    // ============================================================
    // ARRAYS DE PIPELINE
    // pipe_data[STAGES] é a entrada (pós-setup)
    // pipe_data[0] é a saída do último shift
    // ============================================================
    reg [WIDTH-1:0] pipe_data  [STAGES:0]; 
    reg [STAGES-1:0] pipe_shamt [STAGES:0]; // Carrega o shamt pipeline abaixo
    reg             pipe_fill  [STAGES:0];
    reg             pipe_rev   [STAGES:0];
    reg             pipe_valid [STAGES:0];

    // ============================================================
    // ESTÁGIO DE SETUP (Alimenta o índice 'STAGES')
    // ============================================================
    wire [WIDTH-1:0] din_reversed;
    comb_bit_reverser #(.WIDTH(WIDTH)) rev_in (.in_data(din), .out_data(din_reversed));

    wire is_left  = (opcode == 2'b00);
    wire is_arith = (opcode == 2'b10);

    always @(posedge clk) begin
        pipe_data[STAGES]  <= is_left ? din_reversed : din;
        pipe_fill[STAGES]  <= is_arith ? din[WIDTH-1] : 1'b0;
        pipe_rev[STAGES]   <= is_left;
        pipe_shamt[STAGES] <= shamt;
        pipe_valid[STAGES] <= v_in;
    end

    // ============================================================
    // GERAÇÃO DOS ESTÁGIOS DE SHIFT
    // Itera do bit mais significativo (STAGES-1) até 0
    // ============================================================
    genvar i, b;
    generate
        for (i = STAGES - 1; i >= 0; i = i - 1) begin : gen_stages
            // Valor do deslocamento: 2^i (Ex: 8, 4, 2, 1 para Width 16)
            localparam integer SHIFT_AMT = 1 << i;
            
            // Fio para coletar o resultado combinacional deste estágio
            wire [WIDTH-1:0] stage_comb_res;

            // Geração dos Blocos (BLOCK MUX) dentro do Estágio
            for (b = 0; b < WIDTH/BLOCK; b = b + 1) begin : gen_blocks
                comb_block_mux #(
                    .WIDTH(WIDTH), 
                    .BLOCK(BLOCK), 
                    .BLOCK_OFFSET(b*BLOCK), 
                    .SHIFT_AMT(SHIFT_AMT)
                ) u_blk (
                    // Lê do registrador do estágio anterior (i+1)
                    .in_full(pipe_data[i+1]), 
                    // Usa o bit 'i' do shamt armazenado no estágio anterior
                    .do_shift(pipe_shamt[i+1][i]), 
                    .fill_bit(pipe_fill[i+1]),
                    .out_block(stage_comb_res[b*BLOCK +: BLOCK])
                );
            end

            // Registrador de Pipeline para este estágio (Escreve em 'i')
            always @(posedge clk) begin
                pipe_data[i]  <= stage_comb_res;
                pipe_shamt[i] <= pipe_shamt[i+1]; // Propaga o shamt
                pipe_fill[i]  <= pipe_fill[i+1];
                pipe_rev[i]   <= pipe_rev[i+1];
                pipe_valid[i] <= pipe_valid[i+1];
            end
        end
    endgenerate

    // ============================================================
    // ESTÁGIO FINAL (REVERSE OUTPUT)
    // Lê de pipe_data[0]
    // ============================================================
    wire [WIDTH-1:0] data_final_reversed;
    comb_bit_reverser #(.WIDTH(WIDTH)) rev_out (.in_data(pipe_data[0]), .out_data(data_final_reversed));

    always @(posedge clk) begin
        dout  <= pipe_rev[0] ? data_final_reversed : pipe_data[0];
        v_out <= pipe_valid[0];
    end

endmodule
