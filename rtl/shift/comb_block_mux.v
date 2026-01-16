module comb_block_mux #(
    parameter integer WIDTH = 32,
    parameter integer BLOCK = 16,
    parameter integer BLOCK_OFFSET = 0,
    parameter integer SHIFT_AMT = 1
)(
    input  wire [WIDTH-1:0] in_full,
    input  wire             do_shift,
    input  wire             fill_bit,
    output wire [BLOCK-1:0] out_block
);
    genvar j;
    generate
        for (j = 0; j < BLOCK; j = j + 1) begin : bit_logic
            localparam integer my_idx = BLOCK_OFFSET + j;
            localparam integer src_idx = my_idx + SHIFT_AMT;
            if (src_idx < WIDTH) begin
                assign out_block[j] = do_shift ? in_full[src_idx] : in_full[my_idx];
            end else begin
                assign out_block[j] = do_shift ? fill_bit : in_full[my_idx];
            end
        end
    endgenerate
endmodule
