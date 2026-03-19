module fir_filter #(
    parameter N_TAPS  = 8,
    parameter WIDTH   = 16
)(
    input  wire                         clk,
    input  wire                         rst_n,
    input  wire signed [WIDTH-1:0]      data_in,
    input  wire                         data_valid,
    output reg  signed [WIDTH-1:0]      data_out,
    output reg                          out_valid,
    input  wire [$clog2(N_TAPS)-1:0]    coeff_addr,
    input  wire signed [WIDTH-1:0]      coeff_data,
    input  wire                         coeff_wr
);

    localparam ACC_WIDTH = WIDTH*2 + $clog2(N_TAPS);

    reg signed [WIDTH-1:0]     coeffs [0:N_TAPS-1];
    reg signed [WIDTH-1:0]     delay  [0:N_TAPS-1];
    reg signed [ACC_WIDTH-1:0] mac_comb;  // combinational MAC result

    integer j, k;

    // Purely combinational MAC — blocking assignments only, no clk
    always @(*) begin : mac_block
        reg signed [ACC_WIDTH-1:0] acc;
        acc = 0;
        for (j = 0; j < N_TAPS; j = j+1)
            acc = acc + delay[j] * coeffs[j];
        mac_comb = acc;
    end

    // Coefficient write
    always @(posedge clk) begin
        if (coeff_wr)
            coeffs[coeff_addr] <= coeff_data;
    end

    // Sequential: shift register + latch MAC result
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (j = 0; j < N_TAPS; j = j+1)
                delay[j] <= 0;
            data_out  <= 0;
            out_valid <= 0;
        end else if (data_valid) begin
            delay[0] <= data_in;
            for (j = 1; j < N_TAPS; j = j+1)
                delay[j] <= delay[j-1];
            // mac_comb uses OLD delay values (before shift) — correct for FIR
            data_out  <= mac_comb[WIDTH+14:15];
            out_valid <= 1;
        end else begin
            out_valid <= 0;
        end
    end

    initial begin
        for (k = 0; k < N_TAPS; k = k+1)
            coeffs[k] = 0;
        coeffs[0] = 16'h7FFF;
    end

endmodule
