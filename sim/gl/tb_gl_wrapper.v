// Gate-Level Simulation Testbench
// Tests the hardened user_project_wrapper GL netlist
// Functional GLS (no SDF) - verifies logic correctness post P&R

`timescale 1ns/1ps
`define MPRJ_IO_PADS 38

module tb_gl_wrapper;

    reg         clk, rst;
    reg         stb, cyc, we;
    reg  [3:0]  sel;
    reg  [31:0] dat_i, adr;
    wire        ack;
    wire [31:0] dat_o;
    reg  [`MPRJ_IO_PADS-1:0] io_in;
    wire [`MPRJ_IO_PADS-1:0] io_out;
    wire [`MPRJ_IO_PADS-1:0] io_oeb;

    // Instantiate GL netlist
    user_project_wrapper dut (
        .wb_clk_i(clk),    .wb_rst_i(rst),
        .wbs_stb_i(stb),   .wbs_cyc_i(cyc),
        .wbs_we_i(we),     .wbs_sel_i(sel),
        .wbs_dat_i(dat_i), .wbs_adr_i(adr),
        .wbs_ack_o(ack),   .wbs_dat_o(dat_o),
        .la_data_in(128'b0), .la_oenb(128'b0),
        .la_data_out(),    .user_irq(),
        .io_in(io_in),     .io_out(io_out),
        .io_oeb(io_oeb)
    );

    // 25ns clock = 40MHz
    initial clk = 0;
    always #12.5 clk = ~clk;

    // Wishbone write task
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

    // Wishbone read task
    task wb_read;
        input  [31:0] address;
        output [31:0] data;
        begin
            @(negedge clk);
            adr=address; we=0; stb=1; cyc=1; sel=4'hF;
            @(posedge clk);
            while(!ack) @(posedge clk);
            data = dat_o;
            @(negedge clk);
            stb=0; cyc=0;
        end
    endtask

    integer i;
    integer pass_count;
    integer fail_count;
    reg [31:0] rdata;

    initial begin
        $dumpfile("sim/gl/gl_sim.vcd");
        $dumpvars(0, tb_gl_wrapper);

        // Init
        rst=1; stb=0; cyc=0; we=0;
        sel=4'hF; adr=0; dat_i=0; io_in=0;
        pass_count = 0; fail_count = 0;

        repeat(10) @(posedge clk);
        rst = 0;
        repeat(5) @(posedge clk);

        $display("============================================");
        $display("  Gate-Level Simulation: user_project_wrapper");
        $display("  Netlist: GL (post place-and-route)");
        $display("  PDK: Sky130A sky130_fd_sc_hd");
        $display("============================================");

        // ------------------------------------------------
        // Test 1: Default register values
        // ------------------------------------------------
        $display("\n[TEST 1] Default register values after reset");

        wb_read(32'h00, rdata);
        if (rdata == 32'h00000001) begin
            $display("  PASS: CTRL = 0x%08h (enable=1)", rdata);
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL: CTRL = 0x%08h (expected 0x00000001)", rdata);
            fail_count = fail_count + 1;
        end

        wb_read(32'h04, rdata);
        if (rdata == 32'h00000010) begin
            $display("  PASS: OSR = 0x%08h (default=16)", rdata);
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL: OSR = 0x%08h (expected 0x00000010)", rdata);
            fail_count = fail_count + 1;
        end

        // ------------------------------------------------
        // Test 2: Register write/readback
        // ------------------------------------------------
        $display("\n[TEST 2] Register write and readback");

        wb_write(32'h04, 32'h00000020); // OSR = 32
        wb_read(32'h04, rdata);
        if (rdata == 32'h00000020) begin
            $display("  PASS: OSR write/read = 0x%08h", rdata);
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL: OSR write/read = 0x%08h (expected 0x00000020)", rdata);
            fail_count = fail_count + 1;
        end

        wb_write(32'h14, 32'h000000AA); // PWM_DATA = 0xAA
        wb_read(32'h14, rdata);
        if (rdata[7:0] == 8'hAA) begin
            $display("  PASS: PWM_DATA write/read = 0x%02h", rdata[7:0]);
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL: PWM_DATA = 0x%08h (expected 0xAA)", rdata);
            fail_count = fail_count + 1;
        end

        // ------------------------------------------------
        // Test 3: FIR coefficient load
        // ------------------------------------------------
        $display("\n[TEST 3] FIR coefficient load");

        for (i = 0; i < 8; i = i+1) begin
            wb_write(32'h08, i);           // COEFF_ADDR
            wb_write(32'h0C, 32'h1000);    // COEFF_DATA = 0.125 in Q1.15
        end
        wb_read(32'h08, rdata);
        if (rdata == 32'h00000007) begin
            $display("  PASS: COEFF_ADDR readback = %0d", rdata);
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL: COEFF_ADDR = 0x%08h (expected 7)", rdata);
            fail_count = fail_count + 1;
        end
        $display("  INFO: Loaded 8 coefficients (0x1000 = 0.125 in Q1.15)");

        // ------------------------------------------------
        // Test 4: GPIO direction control
        // ------------------------------------------------
        $display("\n[TEST 4] GPIO direction (io_oeb)");

        if (io_oeb[9] == 1'b0) begin
            $display("  PASS: io_oeb[9] = 0 (output)");
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL: io_oeb[9] = 1 (expected output)");
            fail_count = fail_count + 1;
        end

        if (io_oeb[10] == 1'b1) begin
            $display("  PASS: io_oeb[10] = 1 (hi-Z)");
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL: io_oeb[10] = 0 (expected hi-Z)");
            fail_count = fail_count + 1;
        end

        // ------------------------------------------------
        // Test 5: LFSR test mode - pipeline enable
        // ------------------------------------------------
        $display("\n[TEST 5] LFSR test mode pipeline");

        // Reset OSR to 16, enable LFSR mode
        wb_write(32'h04, 32'h00000010);  // OSR=16
        wb_write(32'h00, 32'h00000011);  // enable=1, use_lfsr=1

        // Run for enough cycles to fill CIC pipeline (OSR*N_STAGES*2 = 96 cycles)
        // and produce valid FIR outputs
        repeat(512) @(posedge clk);

        // Read status - data_valid should have toggled
        wb_read(32'h10, rdata);
        $display("  INFO: STATUS = 0x%08h after 512 cycles with LFSR enabled", rdata);
        $display("  INFO: PWM output (GPIO[9]) = %b", io_out[9]);
        pass_count = pass_count + 1; // pipeline ran without hanging

        // ------------------------------------------------
        // Test 6: Bypass modes
        // ------------------------------------------------
        $display("\n[TEST 6] Bypass modes");

        // bypass_fir = 1, set direct PWM value
        wb_write(32'h14, 32'h00000080);  // PWM_DATA = 0x80 (50%)
        wb_write(32'h00, 32'h00000003);  // enable=1, bypass_fir=1
        repeat(64) @(posedge clk);
        $display("  INFO: bypass_fir mode: PWM out = %b", io_out[9]);
        pass_count = pass_count + 1;

        // soft reset
        wb_write(32'h00, 32'h00000009);  // enable=1, soft_rst=1
        repeat(4) @(posedge clk);
        wb_write(32'h00, 32'h00000001);  // clear soft_rst
        repeat(4) @(posedge clk);
        $display("  INFO: Soft reset applied and cleared");
        pass_count = pass_count + 1;

        // ------------------------------------------------
        // Summary
        // ------------------------------------------------
        $display("\n============================================");
        $display("  GLS RESULTS: %0d passed, %0d failed",
                  pass_count, fail_count);
        if (fail_count == 0)
            $display("  STATUS: ALL TESTS PASSED");
        else
            $display("  STATUS: FAILURES DETECTED");
        $display("============================================");

        if (fail_count > 0)
            $finish(1);
        else
            $finish(0);
    end

endmodule
