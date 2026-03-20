// SPDX-FileCopyrightText: 2026 Mummana Jagadeesh
// SPDX-License-Identifier: Apache-2.0

// SPDX-FileCopyrightText: 2026 Mummana Jagadeesh
// SPDX-License-Identifier: Apache-2.0

`timescale 1ns/1ps

module tb_pwm_dac;

    reg         clk, rst_n, enable;
    reg  [7:0]  data_in;
    wire        pwm_out;

    // Instantiate DUT
    pwm_dac #(.WIDTH(8)) dut (
        .clk(clk),
        .rst_n(rst_n),
        .data_in(data_in),
        .enable(enable),
        .pwm_out(pwm_out)
    );

    // Clock: 20ns period = 50MHz
    initial clk = 0;
    always #10 clk = ~clk;

    // Count PWM highs to measure duty cycle
    integer high_count;
    integer total_count;

    task check_duty;
        input [7:0] val;
        input real  expected_pct;
        real actual_pct;
        begin
            data_in    = val;
            high_count = 0;
            total_count = 256;
            repeat(256) begin
                @(posedge clk);
                if (pwm_out) high_count = high_count + 1;
            end
            actual_pct = (high_count * 100.0) / total_count;
            $display("data=0x%02h | highs=%0d/256 | duty=%.1f%% (expected ~%.1f%%)",
                      val, high_count, actual_pct, expected_pct);
        end
    endtask

    initial begin
        $dumpfile("sim/digital/pwm_dac.vcd");
        $dumpvars(0, tb_pwm_dac);

        // Reset
        rst_n  = 0;
        enable = 0;
        data_in = 8'h00;
        repeat(4) @(posedge clk);
        rst_n = 1;
        enable = 1;

        $display("--- PWM DAC Duty Cycle Test ---");
        check_duty(8'h00, 0.0);    // 0%
        check_duty(8'h40, 25.0);   // 25%
        check_duty(8'h80, 50.0);   // 50%
        check_duty(8'hC0, 75.0);   // 75%
        check_duty(8'hFF, 100.0);  // ~100%

        $display("--- Done ---");
        $finish;
    end

endmodule
