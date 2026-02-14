module incrementer_mux_lut #(
    parameter WIDTH = 32,
    parameter BLOCK_SIZE = 8
)(
    input  wire [WIDTH-1:0] data_in,
    output wire [WIDTH-1:0] data_out
);

    localparam NUM_BLOCKS = (WIDTH + BLOCK_SIZE - 1) / BLOCK_SIZE;
    
    // Detecção de blocos cheios
    wire [NUM_BLOCKS-1:0] block_full;
    
    genvar i;
    generate
        for (i = 0; i < NUM_BLOCKS; i = i + 1) begin : detect_full
            localparam START = i * BLOCK_SIZE;
            localparam END = (START + BLOCK_SIZE > WIDTH) ? WIDTH : START + BLOCK_SIZE;
            assign block_full[i] = &data_in[END-1:START];
        end
    endgenerate
    
    // Priority encoder
    wire [NUM_BLOCKS-1:0] target_sel;
    assign target_sel[0] = ~block_full[0];
    
    generate
        for (i = 1; i < NUM_BLOCKS; i = i + 1) begin : priority_enc
            assign target_sel[i] = ~block_full[i] & (&block_full[i-1:0]);
        end
    endgenerate
    
    // MUX de entrada
    wire [BLOCK_SIZE-1:0] selected_value;
    
    generate
        for (i = 0; i < BLOCK_SIZE; i = i + 1) begin : mux_in_bits
            wire [NUM_BLOCKS-1:0] bit_sources;
            
            genvar j;
            for (j = 0; j < NUM_BLOCKS; j = j + 1) begin : gather_bits
                localparam START = j * BLOCK_SIZE;
                localparam END = (START + BLOCK_SIZE > WIDTH) ? WIDTH : START + BLOCK_SIZE;
                
                if (START + i < WIDTH)
                    assign bit_sources[j] = data_in[START + i] & target_sel[j];
                else
                    assign bit_sources[j] = 1'b0;
            end
            
            assign selected_value[i] = |bit_sources;
        end
    endgenerate
    
    // Somador único
    wire [BLOCK_SIZE-1:0] incremented = selected_value + 1'b1;
    
    // Overflow
    wire overflow = &block_full;
    
    // Saída
    generate
        for (i = 0; i < NUM_BLOCKS; i = i + 1) begin : output_blocks
            localparam START = i * BLOCK_SIZE;
            localparam END = (START + BLOCK_SIZE > WIDTH) ? WIDTH : START + BLOCK_SIZE;
            localparam SIZE = END - START;
            
            wire should_zero = |target_sel[NUM_BLOCKS-1:i+1];
            
            assign data_out[END-1:START] = 
                overflow ? {SIZE{1'b0}} :
                target_sel[i] ? incremented[SIZE-1:0] :
                should_zero ? {SIZE{1'b0}} :
                data_in[END-1:START];
        end
    endgenerate

endmodule
