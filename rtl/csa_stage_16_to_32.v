module csa_stage_16_to_32 (
    input               clk,
    input               v_in,

    input  [15:0] sum_in   [0:3],
    input  [15:0] carry_in [0:3],

    output [31:0] sum_out   [0:1],
    output [31:0] carry_out [0:1],
    output              v_out
);

    reg v_pipe;
    always @(posedge clk) begin
        v_pipe <= v_in;
    end

    genvar g;
    generate
        for (g = 0; g < 2; g = g + 1) begin : GEN_16_32
            wire [31:0] sum_c;
            wire [31:0] carry_c;

            csa_pair_reduce #(.WIDTH(16)) u_reduce (
                .sum_a   (sum_in[2*g]),
                .carry_a (carry_in[2*g]),
                .sum_b   (sum_in[2*g+1]),
                .carry_b (carry_in[2*g+1]),
                .sum_out   (sum_c),
                .carry_out (carry_c)
            );

            reg [31:0] sum_r;
            reg [31:0] carry_r;

            always @(posedge clk) begin
                if (v_in) begin
                    sum_r   <= sum_c;
                    carry_r <= carry_c;
                end
            end

            assign sum_out[g]   = sum_r;
            assign carry_out[g] = carry_r;
        end
    endgenerate

    assign v_out = v_pipe;

endmodule
