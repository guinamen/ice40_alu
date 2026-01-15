module pipelined_adder_io #(
    parameter integer WIDTH = 16,
    parameter integer BLOCK = 4
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
