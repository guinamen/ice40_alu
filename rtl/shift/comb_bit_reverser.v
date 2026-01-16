module comb_bit_reverser #(parameter WIDTH = 32) (
    input  wire [WIDTH-1:0] in_data,
    output wire [WIDTH-1:0] out_data
);
    genvar i;
    generate
        for (i = 0; i < WIDTH; i = i + 1) begin : gen_rev
            assign out_data[i] = in_data[WIDTH-1-i];
        end
    endgenerate
endmodule
