`timescale 1ns / 1ps

// =============================================================================
// MÓDULOS AUXILIARES
// =============================================================================

module rca #(parameter integer WIDTH = 4) (
    input  wire [WIDTH-1:0] a, b,
    input  wire             cin,
    output wire [WIDTH-1:0] sum,
    output wire             cout
);
    assign {cout, sum} = a + b + {{(WIDTH-1){1'b0}}, cin};
endmodule

module cs_block #(parameter integer WIDTH = 4) (
    input  wire [WIDTH-1:0] a, b,
    output wire [WIDTH-1:0] sum0, sum1,
    output wire             G, P,
    output wire             c0, c1
);
    rca #(WIDTH) rca0 (.a(a), .b(b), .cin(1'b0), .sum(sum0), .cout(c0));
    rca #(WIDTH) rca1 (.a(a), .b(b), .cin(1'b1), .sum(sum1), .cout(c1));
    assign G = c0;
    assign P = c1 ^ c0;
endmodule

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

module pipelined_adder_core #(
    parameter integer WIDTH = 32,
    parameter integer BLOCK = 8
)(
    input  wire             clk,
    input  wire             v_in,
    input  wire [WIDTH-1:0] a,
    input  wire [WIDTH-1:0] b,
    input  wire             cin,

    output reg  [WIDTH-1:0] sum,
    output reg              v_out
);
    localparam integer NUM_BLOCOS = WIDTH / BLOCK;

    // =========================================================
    // ESTÁGIO 1 — CS BLOCKS
    // =========================================================
    wire [WIDTH-1:0] s0, s1;
    wire [NUM_BLOCOS-1:0] G, P;

    genvar bi;
    generate
        for (bi = 0; bi < NUM_BLOCOS; bi = bi + 1) begin
            cs_block #(BLOCK) cb (
                .a   (a[bi*BLOCK +: BLOCK]),
                .b   (b[bi*BLOCK +: BLOCK]),
                .sum0(s0[bi*BLOCK +: BLOCK]),
                .sum1(s1[bi*BLOCK +: BLOCK]),
                .G   (G[bi]),
                .P   (P[bi])
            );
        end
    endgenerate

    reg [WIDTH-1:0]      est1_s0, est1_s1;
    reg [NUM_BLOCOS-1:0] est1_G, est1_P;
    reg                  est1_cin, v1;

    always @(posedge clk) begin
        if (v_in) begin
            est1_s0  <= s0;
            est1_s1  <= s1;
            est1_G   <= G;
            est1_P   <= P;
            est1_cin <= cin;
        end
        v1 <= v_in;
    end

    // =========================================================
    // ESTÁGIO 2 — PREFIX + SEL REPLICADO
    // =========================================================
    wire [NUM_BLOCOS-1:0] C;

    parallel_prefix_tree #(NUM_BLOCOS) ppt (
        .G_in (est1_G),
        .P_in (est1_P),
        .cin  (est1_cin),
        .C_out(C)
    );

    reg [WIDTH-1:0]      est2_s0, est2_s1;
    reg [NUM_BLOCOS-1:0] sel_a, sel_b;
    reg                  v2;

    always @(posedge clk) begin
        if (v1) begin
            est2_s0 <= est1_s0;
            est2_s1 <= est1_s1;
            sel_a   <= {C[NUM_BLOCOS-2:0], est1_cin};
            sel_b   <= {C[NUM_BLOCOS-2:0], est1_cin};
        end
        v2 <= v1;
    end

    // =========================================================
    // ESTÁGIO 3 — MUX FINAL
    // =========================================================
    integer i;
    always @(posedge clk) begin
        if (v2) begin
            for (i = 0; i < NUM_BLOCOS/2; i = i + 1)
                sum[i*BLOCK +: BLOCK] <= sel_a[i] ?
                                         est2_s1[i*BLOCK +: BLOCK] :
                                         est2_s0[i*BLOCK +: BLOCK];

            for (i = NUM_BLOCOS/2; i < NUM_BLOCOS; i = i + 1)
                sum[i*BLOCK +: BLOCK] <= sel_b[i] ?
                                         est2_s1[i*BLOCK +: BLOCK] :
                                         est2_s0[i*BLOCK +: BLOCK];
        end
        v_out <= v2;
    end
endmodule

module pipelined_adder_io #(
    parameter integer WIDTH = 32,
    parameter integer BLOCK = 8
)(
    input  wire             clk,
    input  wire             v_in,
    input  wire [WIDTH-1:0] a,
    input  wire [WIDTH-1:0] b,
    input  wire             cin,

    output wire [WIDTH-1:0] sum,
    output wire             v_out
);
    // -----------------------------
    // INPUT IOB
    // -----------------------------
    (* IOB = "true" *) reg [WIDTH-1:0] a_iob, b_iob;
    (* IOB = "true" *) reg             cin_iob, v_iob;

    always @(posedge clk) begin
        a_iob <= a;
        b_iob <= b;
        cin_iob <= cin;
        v_iob <= v_in;
    end

    // -----------------------------
    // CORE
    // -----------------------------
    wire [WIDTH-1:0] sum_core;
    wire             v_core;

    pipelined_adder_core #(
        .WIDTH(WIDTH),
        .BLOCK(BLOCK)
    ) core (
        .clk   (clk),
        .v_in  (v_iob),
        .a     (a_iob),
        .b     (b_iob),
        .cin   (cin_iob),
        .sum   (sum_core),
        .v_out (v_core)
    );

    // -----------------------------
    // OUTPUT IOB
    // -----------------------------
    (* IOB = "true" *) reg [WIDTH-1:0] sum_iob;
    (* IOB = "true" *) reg             v_out_iob;

    always @(posedge clk) begin
        sum_iob   <= sum_core;
        v_out_iob <= v_core;
    end

    assign sum   = sum_iob;
    assign v_out = v_out_iob;
endmodule
