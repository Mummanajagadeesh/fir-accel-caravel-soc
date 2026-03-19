// FIR Filter - Direct Form I
// 8 taps, Q1.15 fixed-point coefficients
// Input:  16-bit signed (from CIC)
// Output: 16-bit signed (to PWM DAC)
// Coefficients loaded via Wishbone CSR

module fir_filter #(
    parameter N_TAPS  = 8,
    parameter WIDTH   = 16
)(
    input  wire                         clk,
    input  wire                         rst_n,
    // Data interface
    input  wire signed [WIDTH-1:0]      data_in,
    input  wire                         data_valid,   // from CIC
    output reg  signed [WIDTH-1:0]      data_out,
    output reg                          out_valid,
    // Coefficient load interface
    input  wire [$clog2(N_TAPS)-1:0]    coeff_addr,
    input  wire signed [WIDTH-1:0]      coeff_data,
    input  wire                         coeff_wr
);

    // Coefficient storage
    reg signed [WIDTH-1:0] coeffs [0:N_TAPS-1];

    // Delay line (shift register)
    reg signed [WIDTH-1:0] delay [0:N_TAPS-1];

    // MAC accumulator - wide enough to prevent overflow
    // Q1.15 × Q1.15 = Q2.30, summed 8 times → need Q5.30 = 35 bits
    reg signed [WIDTH*2+$clog2(N_TAPS)-1:0] acc;

    integer j;

    // Coefficient write
    always @(posedge clk) begin
        if (coeff_wr)
            coeffs[coeff_addr] <= coeff_data;
    end

    // Filter operation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (j = 0; j < N_TAPS; j = j+1)
                delay[j] <= 0;
            data_out  <= 0;
            out_valid <= 0;
            acc       <= 0;
        end else if (data_valid) begin
            // Shift delay line
            delay[0] <= data_in;
            for (j = 1; j < N_TAPS; j = j+1)
                delay[j] <= delay[j-1];

            // MAC - accumulate all taps
            acc = 0;
            for (j = 0; j < N_TAPS; j = j+1)
                acc = acc + (delay[j] * coeffs[j]);

            // Truncate back to WIDTH: drop lower 15 bits (Q1.15 product)
            data_out  <= acc[WIDTH+14:15];
            out_valid <= 1;
        end else begin
            out_valid <= 0;
        end
    end

    // Initialize coefficients to identity (passthrough): h[0]=1.0, rest=0
    integer k;
    initial begin
        for (k = 0; k < N_TAPS; k = k+1)
            coeffs[k] = 0;
        coeffs[0] = 16'h7FFF;  // 1.0 in Q1.15
    end

endmodule
