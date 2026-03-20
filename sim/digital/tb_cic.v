// SPDX-FileCopyrightText: 2026 Mummana Jagadeesh
// SPDX-License-Identifier: Apache-2.0

// SPDX-FileCopyrightText: 2026 Mummana Jagadeesh
// SPDX-License-Identifier: Apache-2.0

`timescale 1ns/1ps

module tb_cic;

    reg         clk, rst_n;
    reg         bit_in;
    reg  [6:0]  osr;
    wire [15:0] data_out;
    wire        data_valid;

    cic_decimator #(
        .N_STAGES(3),
        .WIDTH(16),
        .OSR_MAX(64)
    ) dut (
        .clk(clk), .rst_n(rst_n),
        .bit_in(bit_in), .osr(osr),
        .data_out(data_out), .data_valid(data_valid)
    );

    initial clk = 0;
    always #10 clk = ~clk;

    integer valid_count;

    initial begin
        $dumpfile("sim/digital/cic.vcd");
        $dumpvars(0, tb_cic);

        rst_n = 0; bit_in = 0; osr = 16;
        repeat(8) @(posedge clk);
        rst_n = 1;

        $display("--- CIC: DC input (all 1s), OSR=16 ---");
        valid_count = 0;
        repeat(512) begin
            bit_in = 1'b1;
            @(posedge clk);
            if (data_valid) begin
                $display("  valid output[%0d] = %0d (signed: %0d)",
                    valid_count, data_out, $signed(data_out));
                valid_count = valid_count + 1;
            end
        end

        rst_n = 0;
        repeat(4) @(posedge clk);
        rst_n = 1;

        $display("--- CIC: alternating 1/0 (zero mean), OSR=16 ---");
        valid_count = 0;
        repeat(512) begin
            bit_in = ~bit_in;
            @(posedge clk);
            if (data_valid && valid_count < 8) begin
                $display("  valid output[%0d] = %0d (signed: %0d)",
                    valid_count, data_out, $signed(data_out));
                valid_count = valid_count + 1;
            end
        end

        $display("--- Done ---");
        $finish;
    end

endmodule
