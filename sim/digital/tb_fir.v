// SPDX-FileCopyrightText: 2026 Mummana Jagadeesh
// SPDX-License-Identifier: Apache-2.0

// SPDX-FileCopyrightText: 2026 Mummana Jagadeesh
// SPDX-License-Identifier: Apache-2.0

`timescale 1ns/1ps

module tb_fir;

    reg         clk, rst_n;
    reg  signed [15:0] data_in;
    reg         data_valid;
    wire signed [15:0] data_out;
    wire        out_valid;
    reg  [2:0]  coeff_addr;
    reg  signed [15:0] coeff_data;
    reg         coeff_wr;

    // Track last valid input for correct display pairing
    reg signed [15:0] last_input;
    always @(posedge clk)
        if (data_valid) last_input <= data_in;

    fir_filter #(.N_TAPS(8), .WIDTH(16)) dut (
        .clk(clk), .rst_n(rst_n),
        .data_in(data_in), .data_valid(data_valid),
        .data_out(data_out), .out_valid(out_valid),
        .coeff_addr(coeff_addr), .coeff_data(coeff_data),
        .coeff_wr(coeff_wr)
    );

    initial clk = 0;
    always #10 clk = ~clk;

    always @(posedge clk)
        if (out_valid)
            $display("  in=%6d -> out=%6d", last_input, data_out);

    task send_sample;
        input signed [15:0] val;
        begin
            @(negedge clk);
            data_in    = val;
            data_valid = 1;
            @(posedge clk);
            @(negedge clk);
            data_valid = 0;
        end
    endtask

    task load_coeff;
        input [2:0]  addr;
        input signed [15:0] val;
        begin
            @(negedge clk);
            coeff_addr = addr;
            coeff_data = val;
            coeff_wr   = 1;
            @(posedge clk);
            @(negedge clk);
            coeff_wr   = 0;
        end
    endtask

    integer idx;
    integer sum;
    initial begin
        $dumpfile("sim/digital/fir.vcd");
        $dumpvars(0, tb_fir);

        rst_n = 0; data_valid = 0; coeff_wr = 0;
        data_in = 0; coeff_addr = 0; coeff_data = 0;
        repeat(4) @(posedge clk);
        rst_n = 1;
        repeat(2) @(posedge clk);

        // Test 1: passthrough
        $display("--- Test 1: Passthrough (h[0]=1.0) ---");
        send_sample(16'h1000);   // 4096
        send_sample(16'h2000);   // 8192
        send_sample(16'h4000);   // 16384
        send_sample(16'h0000);
        send_sample(16'h0000);
        repeat(4) @(posedge clk);

        // Test 2: 8-tap moving average
        // 1/8 in Q1.15 = 32768/8 = 4096 = 0x1000
        $display("--- Test 2: 8-tap moving average (coeff=0x1000=0.125) ---");
        for (idx = 0; idx < 8; idx = idx+1)
            load_coeff(idx[2:0], 16'h1000);
        repeat(2) @(posedge clk);

        // Impulse: expect 8 outputs each = 32767 * 0.125 = ~4096
        $display("  [impulse then zeros, expect ~4096 x8 then 0]");
        send_sample(16'h7FFF);
        repeat(10) send_sample(16'h0000);
        repeat(4) @(posedge clk);

        // Test 3: step input - ramp up, expect output to average toward step value
        $display("--- Test 3: Step input (DC=0x4000=0.5) ---");
        repeat(16) send_sample(16'h4000);
        repeat(4) @(posedge clk);

        $display("--- Done ---");
        $finish;
    end

endmodule
