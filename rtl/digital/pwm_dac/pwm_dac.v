// SPDX-FileCopyrightText: 2026 Mummana Jagadeesh
// SPDX-License-Identifier: Apache-2.0


// SPDX-License-Identifier: Apache-2.0

// PWM DAC - 8-bit, first-order delta-sigma style
// Input: 8-bit parallel data from Wishbone CSR
// Output: 1-bit PWM on GPIO
// Clock: system clock (up to 50MHz on Sky130)

module pwm_dac #(
    parameter WIDTH = 8
)(
    input  wire             clk,
    input  wire             rst_n,
    input  wire [WIDTH-1:0] data_in,    // 8-bit input value
    input  wire             enable,
    output reg              pwm_out     // 1-bit PWM output
);

    reg [WIDTH:0] accumulator;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            accumulator <= 0;
            pwm_out     <= 0;
        end else if (enable) begin
            // Add input to accumulator, carry is the output
            accumulator <= accumulator[WIDTH-1:0] + data_in;
            pwm_out     <= accumulator[WIDTH];  // overflow bit
        end else begin
            pwm_out <= 0;
        end
    end

endmodule
