// ============================================================================
//  Module: carry_slice4_csa
// ----------------------------------------------------------------------------
//  Description:
//    4-bit Carry-Save Adder (CSA) slice.
//    Generates partial sum and carry vectors without carry propagation.
//
//    This module is designed to be used in a reduction tree for high-frequency
//    arithmetic operations (ADD, SUB, MUL partial products) on LUT-based FPGAs.
//
//  Mathematical Model:
//    value = sum + (carry << 1)
//
//  Architectural Properties:
//    - No carry ripple
//    - No inter-bit dependency
//    - No inter-slice dependency
//    - Fully local combinational logic
//
//  Pipeline Model:
//    - Input register stage
//    - CSA combinational stage
//    - Output register stage
//
//  Notes:
//    - This module does NOT produce a final sum
//    - Carry outputs are NOT shifted
//    - Reduction is performed by external tree logic
//
// ============================================================================

module carry_slice4_csa (
    input         clk,
    input         v_in,

    input  [7:0]  a_in,
    input  [7:0]  b_in,
    input  [7:0]  cin_in,   // Carry-in vector (not propagated)

    output [7:0]  sum,      // Partial sum
    output [7:0]  carry,    // Partial carry (to be shifted externally)
    output        v_out
);

    // ------------------------------------------------------------------------
    // Input register stage
    // ------------------------------------------------------------------------

    reg [7:0] a_r;
    reg [7:0] b_r;
    reg [7:0] cin_r;
    reg       v_pipe;

    always @(posedge clk) begin
        if (v_in) begin
            a_r    <= a_in;
            b_r    <= b_in;
            cin_r  <= cin_in;
            v_pipe <= 1'b1;
        end else begin
            v_pipe <= 1'b0;
        end
    end

    // ------------------------------------------------------------------------
    // CSA combinational logic (no carry propagation)
    // ------------------------------------------------------------------------

    wire [7:0] sum_c;
    wire [7:0] carry_c;

    assign sum_c   = a_r ^ b_r ^ cin_r;

    assign carry_c =
          (a_r & b_r)
        | (a_r & cin_r)
        | (b_r & cin_r);

    // ------------------------------------------------------------------------
    // Output register stage
    // ------------------------------------------------------------------------

    reg [7:0] sum_r;
    reg [7:0] carry_r;
    reg       v_out_r;

    always @(posedge clk) begin
        if (v_pipe) begin
            sum_r   <= sum_c;
            carry_r <= carry_c;
            v_out_r <= 1'b1;
        end else begin
            v_out_r <= 1'b0;
        end
    end

    assign sum   = sum_r;
    assign carry = carry_r;
    assign v_out = v_out_r;

endmodule
