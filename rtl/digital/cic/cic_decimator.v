module cic_decimator #(
    parameter N_STAGES  = 3,
    parameter WIDTH     = 16,
    parameter OSR_MAX   = 64
)(
    input  wire             clk,
    input  wire             rst_n,
    input  wire             bit_in,
    input  wire [6:0]       osr,
    output reg  [WIDTH-1:0] data_out,
    output reg              data_valid
);

    wire signed [WIDTH-1:0] x_in = bit_in ? {{(WIDTH-1){1'b0}}, 1'b1}
                                           : {WIDTH{1'b0}};

    // Integrators
    reg signed [WIDTH-1:0] integ0, integ1, integ2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            integ0 <= 0; integ1 <= 0; integ2 <= 0;
        end else begin
            integ0 <= integ0 + x_in;
            integ1 <= integ1 + integ0;
            integ2 <= integ2 + integ1;
        end
    end

    // Decimation counter
    reg [6:0] dec_cnt;
    reg       dec_pulse;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dec_cnt   <= 0;
            dec_pulse <= 0;
        end else begin
            if (dec_cnt >= osr - 1) begin
                dec_cnt   <= 0;
                dec_pulse <= 1;
            end else begin
                dec_cnt   <= dec_cnt + 1;
                dec_pulse <= 0;
            end
        end
    end

    // Comb stages — unrolled, no loops
    reg signed [WIDTH-1:0] c0_in,  c0_dly,  c0_out;
    reg signed [WIDTH-1:0] c1_in,  c1_dly,  c1_out;
    reg signed [WIDTH-1:0] c2_in,  c2_dly,  c2_out;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            c0_in<=0; c0_dly<=0; c0_out<=0;
            c1_in<=0; c1_dly<=0; c1_out<=0;
            c2_in<=0; c2_dly<=0; c2_out<=0;
            data_out   <= 0;
            data_valid <= 0;
        end else if (dec_pulse) begin
            // Stage 0
            c0_in  <= integ2;
            c0_dly <= c0_in;
            c0_out <= c0_in - c0_dly;
            // Stage 1
            c1_in  <= c0_out;
            c1_dly <= c1_in;
            c1_out <= c1_in - c1_dly;
            // Stage 2
            c2_in  <= c1_out;
            c2_dly <= c2_in;
            c2_out <= c2_in - c2_dly;

            data_out   <= c2_out;
            data_valid <= 1;
        end else begin
            data_valid <= 0;
        end
    end

endmodule
