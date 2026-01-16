module cs_block #(parameter integer WIDTH = 4) (
    input  wire [WIDTH-1:0] a, b,
    output wire [WIDTH-1:0] sum0, sum1,
    output wire             G, P
);
    wire c0;
    wire c1;
    rca_0 #(WIDTH) rca0 (.a(a), .b(b), .sum(sum0), .cout(c0));
    rca_1 #(WIDTH) rca1 (.a(a), .b(b), .sum(sum1), .cout(c1));
    assign G = c0;
    assign P = c1 ^ c0;
endmodule

module parallel_prefix_tree #(parameter integer N = 8) (
    input  wire [N-1:0] G_in, P_in,
    input  wire         cin,
    output wire [N-2:0] C_chain,
    output wire C_out
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
        for (j = 0; j < N - 1; j = j + 1)
            assign C_chain[j] = g[DEPTH][j] | (p[DEPTH][j] & cin);
    endgenerate
    assign C_out = g[DEPTH][N-1] | (p[DEPTH][N-1] & cin);
endmodule
