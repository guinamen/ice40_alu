// ============================================================================
//  Module: csa_pair_reduce
// ----------------------------------------------------------------------------
//  Description:
//    Reduces two CSA-formatted vectors of WIDTH bits into a single
//    CSA-formatted vector of 2*WIDTH bits.
//
//    Input representation:
//      value = sum + (carry << 1)
//
//    Output representation:
//      value = sum_out + (carry_out << 1)
//
//  Properties:
//    - No carry propagation
//    - Pure combinational logic
//    - Designed for hierarchical CSA reduction trees
// ============================================================================

module csa_pair_reduce #(
    parameter WIDTH = 8
)(
    input  [WIDTH-1:0] sum_a,
    input  [WIDTH-1:0] carry_a,

    input  [WIDTH-1:0] sum_b,
    input  [WIDTH-1:0] carry_b,

    output [2*WIDTH-1:0] sum_out,
    output [2*WIDTH-1:0] carry_out
);

    // ------------------------------------------------------------------------
    // Align inputs into 2*WIDTH vectors
    // ------------------------------------------------------------------------

    wire [2*WIDTH-1:0] a_vec;
    wire [2*WIDTH-1:0] b_vec;
    wire [2*WIDTH-1:0] c_vec;

    // sum vectors occupy lower WIDTH bits
    assign a_vec = {{WIDTH{1'b0}}, sum_a};
    assign b_vec = {{WIDTH{1'b0}}, sum_b};

    // carry vectors are conceptually shifted left by 1
    assign c_vec =
          {{(WIDTH-1){1'b0}}, carry_a, 1'b0}
        | {{(WIDTH-1){1'b0}}, carry_b, 1'b0};

    // ------------------------------------------------------------------------
    // CSA reduction: a_vec + b_vec + c_vec
    // ------------------------------------------------------------------------

    assign sum_out   = a_vec ^ b_vec ^ c_vec;
    assign carry_out = (a_vec & b_vec)
                     | (a_vec & c_vec)
                     | (b_vec & c_vec);

endmodule
