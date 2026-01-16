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
    wire [NUM_BLOCOS-2:0] C;

    parallel_prefix_tree #(NUM_BLOCOS) ppt (
        .G_in (est1_G),
        .P_in (est1_P),
        .cin  (est1_cin),
        .C_chain(C)
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
