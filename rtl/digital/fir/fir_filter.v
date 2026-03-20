// SPDX-FileCopyrightText: 2026 Mummana Jagadeesh
// SPDX-License-Identifier: Apache-2.0


// SPDX-License-Identifier: Apache-2.0

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
    reg signed [ACC_WIDTH-1:0] mac_comb;

    integer j;

    // Combinational MAC
    always @(*) begin : mac_block
        reg signed [ACC_WIDTH-1:0] acc;
        integer k;
        acc = 0;
        for (k = 0; k < N_TAPS; k = k+1)
            acc = acc + delay[k] * coeffs[k];
        mac_comb = acc;
    end

    // Coefficient write + reset to passthrough (h[0]=1.0, rest=0)
    always @(posedge clk or negedge rst_n) begin : coeff_block
        integer m;
        if (!rst_n) begin
            for (m = 0; m < N_TAPS; m = m+1)
                coeffs[m] <= 0;
            coeffs[0] <= 16'h7FFF;  // 1.0 in Q1.15 — passthrough default
        end else if (coeff_wr) begin
            coeffs[coeff_addr] <= coeff_data;
        end
    end

    // Delay line + output register
    always @(posedge clk or negedge rst_n) begin : filter_block
        integer n;
        if (!rst_n) begin
            for (n = 0; n < N_TAPS; n = n+1)
                delay[n] <= 0;
            data_out  <= 0;
            out_valid <= 0;
        end else if (data_valid) begin
            delay[0] <= data_in;
            for (n = 1; n < N_TAPS; n = n+1)
                delay[n] <= delay[n-1];
            data_out  <= mac_comb[WIDTH+14:15];
            out_valid <= 1;
        end else begin
            out_valid <= 0;
        end
    end

endmodule
