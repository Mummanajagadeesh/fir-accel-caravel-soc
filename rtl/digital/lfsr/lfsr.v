// SPDX-FileCopyrightText: 2026 Mummana Jagadeesh
// SPDX-License-Identifier: Apache-2.0


// SPDX-License-Identifier: Apache-2.0

module lfsr (
    input  wire clk,
    input  wire rst_n,
    input  wire enable,
    output wire bit_out
);
    reg [15:0] state;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= 16'hACE1;
        else if (enable)
            state <= {state[14:0], 1'b0} ^
                     ({16{state[15]}} & 16'hB400);
    end
    assign bit_out = state[15];
endmodule
