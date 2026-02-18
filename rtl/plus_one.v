module plus_one #(
    parameter WIDTH      = 32,
    parameter BLOCK_SIZE = 2
)(
    input  wire [WIDTH-1:0] data_in,
    output wire [WIDTH-1:0] data_out
);
    localparam NUM_BLOCKS = (WIDTH + BLOCK_SIZE - 1) / BLOCK_SIZE;
    localparam LEVELS     = $clog2(NUM_BLOCKS);  // níveis da árvore

    // ─────────────────────────────────────────────────
    // 1. Detecção de blocos cheios (inalterada)
    // ─────────────────────────────────────────────────
    wire [NUM_BLOCKS-1:0] block_full;

    genvar i;
    generate
        for (i = 0; i < NUM_BLOCKS; i = i + 1) begin : detect_full
            localparam START = i * BLOCK_SIZE;
            localparam END   = (START + BLOCK_SIZE > WIDTH) ? WIDTH : START + BLOCK_SIZE;
            assign block_full[i] = &data_in[END-1:START];
        end
    endgenerate

    // ─────────────────────────────────────────────────
    // 2. Árvore de prefixo — AND paralelo
    //    prefix[lvl][i] = AND de block_full[0..i]
    //    cobrindo stride 2^lvl
    // ─────────────────────────────────────────────────
    wire [NUM_BLOCKS-1:0] prefix [0:LEVELS];

    // Nível base: cada elemento é o próprio block_full
    assign prefix[0] = block_full;

    genvar lvl;
    generate
        for (lvl = 0; lvl < LEVELS; lvl = lvl + 1) begin : prefix_levels
            localparam STRIDE = 1 << lvl;
            for (i = 0; i < NUM_BLOCKS; i = i + 1) begin : prefix_bits
                if (i >= STRIDE)
                    // combina com o elemento STRIDE posições atrás
                    assign prefix[lvl+1][i] = prefix[lvl][i] & prefix[lvl][i-STRIDE];
                else
                    // não tem elemento anterior suficiente — passa direto
                    assign prefix[lvl+1][i] = prefix[lvl][i];
            end
        end
    endgenerate

    // all_full_below[i] = AND de block_full[0..i-1]
    // (prefixo exclusivo: não inclui o bloco i)
    wire [NUM_BLOCKS-1:0] all_full_below;
    assign all_full_below[0] = 1'b1; // vácuo — nenhum predecessor

    generate
        for (i = 1; i < NUM_BLOCKS; i = i + 1) begin : excl_prefix
            assign all_full_below[i] = prefix[LEVELS][i-1];
        end
    endgenerate

    // ─────────────────────────────────────────────────
    // 3. target_sel em O(log N) em vez de O(N)
    //    bloco i é o alvo se:
    //    - não está cheio
    //    - todos os blocos abaixo estão cheios
    // ─────────────────────────────────────────────────
    wire [NUM_BLOCKS-1:0] target_sel;

    generate
        for (i = 0; i < NUM_BLOCKS; i = i + 1) begin : gen_target
            assign target_sel[i] = ~block_full[i] & all_full_below[i];
        end
    endgenerate

    // ─────────────────────────────────────────────────
    // 4. MUX de entrada — extrai bloco selecionado
    // ─────────────────────────────────────────────────
    wire [BLOCK_SIZE-1:0] selected_value;

    genvar j;
    generate
        for (i = 0; i < BLOCK_SIZE; i = i + 1) begin : mux_in_bits
            wire [NUM_BLOCKS-1:0] bit_sources;

            for (j = 0; j < NUM_BLOCKS; j = j + 1) begin : gather_bits
                localparam START = j * BLOCK_SIZE;
                if (START + i < WIDTH)
                    assign bit_sources[j] = data_in[START + i] & target_sel[j];
                else
                    assign bit_sources[j] = 1'b0;
            end

            assign selected_value[i] = |bit_sources;
        end
    endgenerate

    // ─────────────────────────────────────────────────
    // 5. Somador único — cabe numa carry chain curta
    // ─────────────────────────────────────────────────
    wire [BLOCK_SIZE-1:0] incremented = selected_value + 1'b1;

    // ─────────────────────────────────────────────────
    // 6. Overflow global
    // ─────────────────────────────────────────────────
    wire overflow = prefix[LEVELS][NUM_BLOCKS-1]; // AND de todos os blocos

    // ─────────────────────────────────────────────────
    // 7. Saída — corrige should_zero do último bloco
    // ─────────────────────────────────────────────────
    generate
        for (i = 0; i < NUM_BLOCKS; i = i + 1) begin : output_blocks
            localparam START = i * BLOCK_SIZE;
            localparam END   = (START + BLOCK_SIZE > WIDTH) ? WIDTH : START + BLOCK_SIZE;
            localparam SIZE  = END - START;

            // blocos abaixo do alvo devem ser zerados (carry os consumiu)
            // usa o prefixo exclusivo do bloco ACIMA de i:
            // se algum bloco j > i for o alvo, então i deve zerar
            wire should_zero;
            if (i < NUM_BLOCKS - 1)
                // existe algum target_sel ativo acima de i?
                assign should_zero = |target_sel[NUM_BLOCKS-1:i+1];
            else
                // último bloco nunca zera por carry
                assign should_zero = 1'b0;

            assign data_out[END-1:START] =
                overflow      ? {SIZE{1'b0}}      :
                target_sel[i] ? incremented[SIZE-1:0] :
                should_zero   ? {SIZE{1'b0}}      :
                                data_in[END-1:START];
        end
    endgenerate

endmodule
