module parallel_prefix_tree #(parameter integer N = 8) (
    input  wire [N-1:0] G_in, P_in,
    input  wire         cin,
    output wire [N-1:0] C_out
);
    localparam DEPTH = $clog2(N);
    wire [N-1:0] g [0:DEPTH];
    wire [N-1:0] p [0:DEPTH];

    assign g[0] = G_in;
    assign p[0] = P_in;

    genvar i, j;
    generate
        for (i = 0; i < DEPTH; i = i + 1) begin
            localparam integer D = 1 << i;
            for (j = 0; j < N; j = j + 1) begin
                if (j < D) begin
                    assign g[i+1][j] = g[i][j];
                    assign p[i+1][j] = p[i][j];
                end else begin
                    assign g[i+1][j] = g[i][j] | (p[i][j] & g[i][j-D]);
                    assign p[i+1][j] = p[i][j] & p[i][j-D];
                end
            end
        end
        for (j = 0; j < N; j = j + 1)
            assign C_out[j] = g[DEPTH][j] | (p[DEPTH][j] & cin);
    endgenerate
endmodule
