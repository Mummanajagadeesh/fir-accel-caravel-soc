// SPDX-FileCopyrightText: 2026 Mummana Jagadeesh
// SPDX-License-Identifier: Apache-2.0

// SPDX-FileCopyrightText: 2026 Mummana Jagadeesh
// SPDX-License-Identifier: Apache-2.0

`timescale 1ns/1ps

module tb_wb_csr;

    reg         clk, rst;
    reg         stb, cyc, we;
    reg  [3:0]  sel;
    reg  [31:0] dat_i, adr;
    wire        ack;
    wire [31:0] dat_o;

    // Outputs
    wire        enable, bypass_fir, bypass_cic, soft_rst;
    wire [6:0]  osr;
    wire [2:0]  coeff_addr;
    wire [15:0] coeff_data;
    wire        coeff_wr;
    wire [7:0]  pwm_direct;

    wb_csr dut (
        .wb_clk_i(clk), .wb_rst_i(rst),
        .wbs_stb_i(stb), .wbs_cyc_i(cyc),
        .wbs_we_i(we),   .wbs_sel_i(sel),
        .wbs_dat_i(dat_i),.wbs_adr_i(adr),
        .wbs_ack_o(ack), .wbs_dat_o(dat_o),
        .enable(enable), .bypass_fir(bypass_fir),
        .bypass_cic(bypass_cic), .soft_rst(soft_rst),
        .osr(osr), .coeff_addr(coeff_addr),
        .coeff_data(coeff_data), .coeff_wr(coeff_wr),
        .pwm_direct(pwm_direct),
        .data_valid(1'b1), .overflow(1'b0)
    );

    initial clk = 0;
    always #10 clk = ~clk;

    task wb_write;
        input [31:0] address;
        input [31:0] data;
        begin
            @(negedge clk);
            adr = address; dat_i = data;
            we = 1; stb = 1; cyc = 1; sel = 4'hF;
            @(posedge clk);
            while (!ack) @(posedge clk);
            @(negedge clk);
            stb = 0; cyc = 0; we = 0;
        end
    endtask

    task wb_read;
        input  [31:0] address;
        output [31:0] data;
        begin
            @(negedge clk);
            adr = address; we = 0;
            stb = 1; cyc = 1; sel = 4'hF;
            @(posedge clk);
            while (!ack) @(posedge clk);
            data = dat_o;
            @(negedge clk);
            stb = 0; cyc = 0;
        end
    endtask

    reg [31:0] rdata;
    initial begin
        $dumpfile("sim/digital/wb_csr.vcd");
        $dumpvars(0, tb_wb_csr);

        rst = 1; stb = 0; cyc = 0; we = 0;
        sel = 4'hF; adr = 0; dat_i = 0;
        repeat(4) @(posedge clk);
        rst = 0;
        repeat(2) @(posedge clk);

        // Check defaults
        $display("--- Default register check ---");
        wb_read(32'h00, rdata);
        $display("  CTRL    = 0x%08h (expect 0x00000001)", rdata);
        wb_read(32'h04, rdata);
        $display("  OSR     = 0x%08h (expect 0x00000010)", rdata);

        // Write OSR=32
        $display("--- Write OSR=32 ---");
        wb_write(32'h04, 32'h00000020);
        wb_read(32'h04, rdata);
        $display("  OSR     = 0x%08h (expect 0x00000020)", rdata);
        $display("  osr out = %0d (expect 32)", osr);

        // Write coefficient
        $display("--- Load coeff tap2 = 0x1000 ---");
        wb_write(32'h08, 32'h00000002); // coeff_addr = 2
        wb_write(32'h0C, 32'h00001000); // coeff_data = 0x1000, pulses coeff_wr
        $display("  coeff_addr=%0d coeff_data=0x%04h coeff_wr=%0b",
                  coeff_addr, coeff_data, coeff_wr);

        // Read status
        $display("--- Status read ---");
        wb_read(32'h10, rdata);
        $display("  STATUS  = 0x%08h (expect 0x00000001, data_valid=1)", rdata);

        // Set bypass_fir
        $display("--- Set bypass_fir ---");
        wb_write(32'h00, 32'h00000003); // enable=1, bypass_fir=1
        $display("  enable=%0b bypass_fir=%0b (expect 1,1)", enable, bypass_fir);

        $display("--- Done ---");
        $finish;
    end

endmodule
