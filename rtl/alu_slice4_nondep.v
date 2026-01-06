// ============================================================================
//  Module: alu_slice4_nondep
// ----------------------------------------------------------------------------
//  Description:
//    4-bit ALU execution slice without inter-slice dependencies.
//    Designed for high-frequency operation on low-cost LUT-based FPGAs.
//
//    This module represents a pure EXECUTE stage. All decode and control
//    signals are assumed to be generated, validated, and REGISTERED in a
//    previous pipeline stage (Decode).
//
//  Architectural Contract:
//    - Operands and operation control signals arrive already registered
//    - Operation control signals are one-hot encoded
//    - Control signals are stable when v_in is asserted
//    - This module contains NO decode logic
//
//  Pipeline Model:
//    Stage D (Decode, external):
//      - Instruction decode
//      - One-hot operation generation
//      - Registering of operands and control signals
//
//    Stage X (Execute, this module):
//      - Local operand capture (optional buffering)
//      - Fully parallel ALU computation
//      - Mask-based operation selection (no multiplexers)
//
//    Stage W (Writeback, local):
//      - Result register
//      - Validity propagation
//
//  FPGA-Oriented Design Techniques:
//    - No wide multiplexers on critical path
//    - No carry propagation
//    - One-hot control with logical masking
//    - Clock-enable inferred via validity signal
//    - No resets, no speculative gating
//
//  Notes:
//    - Control signals are NOT registered here by design
//    - Registering them in this module would duplicate decode functionality
//    - Invalid cycles preserve previous data but deassert validity
//
// ============================================================================

module alu_slice4_nondep (
    input         clk,
    input         v_in,     // Valid input from registered decode stage

    input  [3:0]  a_in,     // Operand A (already registered)
    input  [3:0]  b_in,     // Operand B (already registered)

    // One-hot operation controls (registered in decode stage)
    input         do_and,
    input         do_or,
    input         do_xor,
    input         do_not,
    input         do_pass,

    output [3:0]  result,   // Registered result
    output        v_out     // Output validity
);

    // ------------------------------------------------------------------------
    // Optional local operand buffering
    // Provides placement isolation and limits fanout.
    // ------------------------------------------------------------------------

    reg [3:0] a_r;
    reg [3:0] b_r;
    reg       v_pipe;

    always @(posedge clk) begin
        if (v_in) begin
            a_r    <= a_in;
            b_r    <= b_in;
            v_pipe <= 1'b1;
        end else begin
            v_pipe <= 1'b0;
        end
    end

    // ------------------------------------------------------------------------
    // Execute stage: fully parallel ALU logic
    // Control signals are assumed stable and registered externally.
    // ------------------------------------------------------------------------

    wire [3:0] and_res  = a_r & b_r;
    wire [3:0] or_res   = a_r | b_r;
    wire [3:0] xor_res  = a_r ^ b_r;
    wire [3:0] not_res  = ~a_r;
    wire [3:0] pass_res = a_r;

    wire [3:0] result_c =
          ({4{do_and }} & and_res )
        | ({4{do_or  }} & or_res  )
        | ({4{do_xor }} & xor_res )
        | ({4{do_not }} & not_res )
        | ({4{do_pass}} & pass_res);

    // ------------------------------------------------------------------------
    // Writeback stage
    // ------------------------------------------------------------------------

    reg [3:0] result_r;
    reg       v_out_r;

    always @(posedge clk) begin
        if (v_pipe) begin
            result_r <= result_c;
            v_out_r  <= 1'b1;
        end else begin
            v_out_r  <= 1'b0;
        end
    end

    assign result = result_r;
    assign v_out  = v_out_r;

endmodule
