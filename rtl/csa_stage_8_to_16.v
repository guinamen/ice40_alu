module csa_stage_8_to_16 (
    input               clk,
    input               v_in,

    input  [7:0]  sum_in   [0:7],
    input  [7:0]  carry_in [0:7],

    output [15:0] sum_out   [0:3],
    output [15:0] carry_out [0:3],
    output              v_out
);

    integer i;
    reg v_pipe;

    always @(posedge clk) begin
        v_pipe <= v_in;
    end

    genvar g;
    generate
        for (g = 0; g < 4; g = g + 1) begin : GEN_8_16
            wire [15:0] sum_c;
            wire [15:0] carry_c;

            csa_pair_reduce #(.WIDTH(8)) u_reduce (
                .sum_a   (sum_in[2*g]),
                .carry_a (carry_in[2*g]),
                .sum_b   (sum_in[2*g+1]),
                .carry_b (carry_in[2*g+1]),
                .sum_out   (sum_c),
                .carry_out (carry_c)
            );

            reg [15:0] sum_r;
            reg [15:0] carry_r;

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
