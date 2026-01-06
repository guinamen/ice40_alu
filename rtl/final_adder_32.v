// ============================================================================
//  Module: final_adder_32
// ----------------------------------------------------------------------------
//  Description:
//    Final adder stage for CSA-based arithmetic datapath.
//    Converts CSA representation (sum, carry) into a 32-bit result using
//    a single-cycle ripple adder.
//
//    Input representation:
//      value = sum + (carry << 1)
//
//    Notes:
//    - Carry propagation occurs only in this stage
//    - Designed for FPGA carry-chain utilization
//    - Signed/unsigned interpretation is external (RISC-V agnostic)
// ============================================================================

module final_adder_32 (
    input              clk,
    input              v_in,

    input  [31:0]      sum_in,
    input  [31:0]      carry_in,

    output [31:0]      result,
    output             v_out
);

    // ------------------------------------------------------------------------
    // Align carry
    // ------------------------------------------------------------------------
    wire [31:0] carry_shifted;
    assign carry_shifted = carry_in << 1;

    // ------------------------------------------------------------------------
    // Ripple add (maps directly to FPGA carry-chain)
    // ------------------------------------------------------------------------
    wire [32:0] full_sum;
    assign full_sum = {1'b0, sum_in} + {1'b0, carry_shifted};

    // ------------------------------------------------------------------------
    // Output registers
    // ------------------------------------------------------------------------
    reg [31:0] result_r;
    reg        v_out_r;

    always @(posedge clk) begin
        if (v_in) begin
            result_r <= full_sum[31:0];
            v_out_r  <= 1'b1;
        end else begin
            v_out_r  <= 1'b0;
        end
    end

    assign result = result_r;
    assign v_out  = v_out_r;

endmodule
