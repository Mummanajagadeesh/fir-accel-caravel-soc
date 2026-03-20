// SPDX-FileCopyrightText: 2026 Mummana Jagadeesh
// SPDX-License-Identifier: Apache-2.0

// SPDX-FileCopyrightText: 2026 Mummana Jagadeesh
// SPDX-License-Identifier: Apache-2.0

`timescale 1ns/1ps
`define MPRJ_IO_PADS 38

module tb_top;

    reg         clk, rst;
    reg         stb, cyc, we;
    reg  [3:0]  sel;
    reg  [31:0] dat_i, adr;
    wire        ack;
    wire [31:0] dat_o;
    reg  [`MPRJ_IO_PADS-1:0] io_in;
    wire [`MPRJ_IO_PADS-1:0] io_out, io_oeb;

    user_project_wrapper dut (
        .wb_clk_i(clk),   .wb_rst_i(rst),
        .wbs_stb_i(stb),  .wbs_cyc_i(cyc),
        .wbs_we_i(we),    .wbs_sel_i(sel),
        .wbs_dat_i(dat_i),.wbs_adr_i(adr),
        .wbs_ack_o(ack),  .wbs_dat_o(dat_o),
        .la_data_in(128'b0), .la_oenb(128'b0),
        .la_data_out(),   .user_irq(),
        .io_in(io_in),    .io_out(io_out), .io_oeb(io_oeb)
    );

    initial clk = 0;
    always #10 clk = ~clk;

    task wb_write;
        input [31:0] address;
        input [31:0] data;
        begin
            @(negedge clk);
            adr=address; dat_i=data; we=1; stb=1; cyc=1; sel=4'hF;
            @(posedge clk);
            while(!ack) @(posedge clk);
            @(negedge clk);
            stb=0; cyc=0; we=0;
        end
    endtask

    integer i;
    initial begin
        $dumpfile("sim/digital/top.vcd");
        $dumpvars(0, tb_top);

        rst=1; stb=0; cyc=0; we=0;
        sel=4'hF; adr=0; dat_i=0; io_in=0;
        repeat(4) @(posedge clk);
        rst=0;
        repeat(2) @(posedge clk);

        $display("--- Integration smoke test ---");

        // Set OSR=16, enable
        wb_write(32'h04, 32'h00000010);
        wb_write(32'h00, 32'h00000001);

        // Load moving average coefficients
        for (i = 0; i < 8; i = i+1) begin
            wb_write(32'h08, i);
            wb_write(32'h0C, 32'h00001000);
        end

        // Drive alternating bitstream on GPIO[8]
        $display("  Driving bitstream on GPIO[8]...");
        repeat(512) begin
            @(negedge clk);
            io_in[8] = ~io_in[8];
        end

        @(posedge clk);
        $display("  PWM out  (GPIO[9])  = %b", io_out[9]);
        $display("  OEB[9]              = %b (expect 0)", io_oeb[9]);
        $display("  OEB[10]             = %b (expect 1)", io_oeb[10]);
        $display("--- Done ---");
        $finish;
    end

endmodule
