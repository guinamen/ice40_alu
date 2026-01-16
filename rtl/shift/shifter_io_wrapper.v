module shifter_io_wrapper #(
    parameter integer WIDTH = 16,
    parameter integer BLOCK = 8
)(
    input  wire             clk,
    input  wire             v_in,
    input  wire [1:0]       opcode,
    // Tamanho do Shamt dinâmico no IO também
    input  wire [$clog2(WIDTH)-1:0] shamt, 
    input  wire [WIDTH-1:0] din,
    
    output wire [WIDTH-1:0] dout,
    output wire             v_out
);
    // Função local para o wrapper
    function integer clog2;
        input integer value;
        begin
            value = value - 1;
            for (clog2 = 0; value > 0; clog2 = clog2 + 1)
                value = value >> 1;
        end
    endfunction

    localparam SHAMT_W = clog2(WIDTH);

    // ------------------------------------
    // INPUT IOBs
    // ------------------------------------
    (* IOB = "true" *) reg [WIDTH-1:0] din_iob;
    (* IOB = "true" *) reg [1:0]       opcode_iob;
    (* IOB = "true" *) reg [SHAMT_W-1:0] shamt_iob;
    (* IOB = "true" *) reg             v_iob;

    always @(posedge clk) begin
        din_iob    <= din;
        opcode_iob <= opcode;
        shamt_iob  <= shamt;
        v_iob      <= v_in;
    end

    // ------------------------------------
    // INSTÂNCIA DO CORE GENÉRICO
    // ------------------------------------
    wire [WIDTH-1:0] core_out;
    wire             core_vout;

    pipelined_shifter_core #(
        .WIDTH(WIDTH),
        .BLOCK(BLOCK)
    ) u_core (
        .clk   (clk),
        .opcode(opcode_iob),
        .shamt (shamt_iob),
        .v_in  (v_iob),
        .din   (din_iob),
        .dout  (core_out),
        .v_out (core_vout)
    );

    // ------------------------------------
    // OUTPUT IOBs
    // ------------------------------------
    (* IOB = "true" *) reg [WIDTH-1:0] dout_iob;
    (* IOB = "true" *) reg             v_out_iob;

    always @(posedge clk) begin
        dout_iob  <= core_out;
        v_out_iob <= core_vout;
    end

    assign dout  = dout_iob;
    assign v_out = v_out_iob;

endmodule
