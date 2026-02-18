module plus_one #(
    parameter WIDTH      = 32,
    parameter BLOCK_SIZE = 2
)(
    input  wire [WIDTH-1:0] data_in,
    output wire [WIDTH-1:0] data_out
);
    localparam NUM_BLOCKS = (WIDTH + BLOCK_SIZE - 1) / BLOCK_SIZE;
    localparam LEVELS     = $clog2(NUM_BLOCKS);

    // ─────────────────────────────────────────────────
    // 1. Detecção de blocos cheios
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
    // 2. Árvore de prefixo AND paralela
    //    prefix[LEVELS][i] = AND de block_full[0..i]
    // ─────────────────────────────────────────────────
    wire [NUM_BLOCKS-1:0] prefix [0:LEVELS];

    assign prefix[0] = block_full;

    genvar lvl;
    generate
        for (lvl = 0; lvl < LEVELS; lvl = lvl + 1) begin : prefix_levels
            localparam STRIDE = 1 << lvl;
            for (i = 0; i < NUM_BLOCKS; i = i + 1) begin : prefix_bits
                if (i >= STRIDE)
                    assign prefix[lvl+1][i] = prefix[lvl][i] & prefix[lvl][i-STRIDE];
                else
                    assign prefix[lvl+1][i] = prefix[lvl][i];
            end
        end
    endgenerate

    // all_full_below[i] = AND de block_full[0..i-1] (prefixo exclusivo)
    wire [NUM_BLOCKS-1:0] all_full_below;
    assign all_full_below[0] = 1'b1;

    generate
        for (i = 1; i < NUM_BLOCKS; i = i + 1) begin : excl_prefix
            assign all_full_below[i] = prefix[LEVELS][i-1];
        end
    endgenerate

    // ─────────────────────────────────────────────────
    // 3. Overflow global
    // ─────────────────────────────────────────────────
    wire overflow = prefix[LEVELS][NUM_BLOCKS-1];

    // ─────────────────────────────────────────────────
    // 4. Somadores locais paralelos — independentes de
    //    target_sel, eliminam o MUX de entrada do
    //    caminho crítico
    // ─────────────────────────────────────────────────
    wire [BLOCK_SIZE-1:0] local_inc [0:NUM_BLOCKS-1];

    generate
        for (i = 0; i < NUM_BLOCKS; i = i + 1) begin : precompute_inc
            localparam START = i * BLOCK_SIZE;
            localparam END   = (START + BLOCK_SIZE > WIDTH) ? WIDTH : START + BLOCK_SIZE;
            assign local_inc[i] = data_in[END-1:START] + 1'b1;
        end
    endgenerate

    // ─────────────────────────────────────────────────
    // 5. Saída
    //
    //    Para o bloco i, define-se:
    //      is_target[i]  = ~block_full[i] & all_full_below[i]
    //                    → bloco i recebe incremento local
    //      is_below[i]   =  block_full[i] & all_full_below[i]
    //                    → bloco i está cheio E abaixo do alvo
    //                      (carry o consumiu → deve zerar)
    //
    //    Isso substitui a redução OR sobre target_sel que
    //    gerava o caminho crítico anterior (should_zero).
    //
    //    Caminho crítico resultante:
    //      data_in → block_full → prefixo AND → all_full_below
    //              → MUX de saída
    // ─────────────────────────────────────────────────
    generate
        for (i = 0; i < NUM_BLOCKS; i = i + 1) begin : output_blocks
            localparam START = i * BLOCK_SIZE;
            localparam END   = (START + BLOCK_SIZE > WIDTH) ? WIDTH : START + BLOCK_SIZE;
            localparam SIZE  = END - START;

            wire is_target = ~block_full[i] & all_full_below[i];
            wire is_below  =  block_full[i] & all_full_below[i];

            assign data_out[END-1:START] =
                overflow  ? {SIZE{1'b0}}              :
                is_target ? local_inc[i][SIZE-1:0]    :
                is_below  ? {SIZE{1'b0}}              :
                            data_in[END-1:START];
        end
    endgenerate

endmodule
