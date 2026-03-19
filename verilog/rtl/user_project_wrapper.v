// SPDX-FileCopyrightText: 2020 Efabless Corporation
// Licensed under the Apache License, Version 2.0
`default_nettype none

`ifndef MPRJ_IO_PADS
  `define MPRJ_IO_PADS 38
`endif

module user_project_wrapper #(
    parameter BITS = 32
)(
`ifdef USE_POWER_PINS
    inout vdda1, inout vdda2, inout vssa1, inout vssa2,
    inout vccd1, inout vccd2, inout vssd1, inout vssd2,
`endif
    input  wire         wb_clk_i,
    input  wire         wb_rst_i,
    input  wire         wbs_stb_i,
    input  wire         wbs_cyc_i,
    input  wire         wbs_we_i,
    input  wire [3:0]   wbs_sel_i,
    input  wire [31:0]  wbs_dat_i,
    input  wire [31:0]  wbs_adr_i,
    output wire         wbs_ack_o,
    output wire [31:0]  wbs_dat_o,
    input  wire [127:0] la_data_in,
    output wire [127:0] la_data_out,
    input  wire [127:0] la_oenb,
    input  wire [`MPRJ_IO_PADS-1:0] io_in,
    output wire [`MPRJ_IO_PADS-1:0] io_out,
    output wire [`MPRJ_IO_PADS-1:0] io_oeb,
    output wire [2:0]   user_irq
);

    // --- Internal wires ---
    wire        enable, bypass_fir, bypass_cic, soft_rst;
    wire [6:0]  osr;
    wire [2:0]  coeff_addr;
    wire [15:0] coeff_data;
    wire        coeff_wr;
    wire [7:0]  pwm_direct;
    wire        bit_in;
    wire        cic_valid;
    wire [15:0] cic_out;
    wire        fir_valid;
    wire [15:0] fir_out;
    wire        pwm_out;

    // GPIO assignments
    assign bit_in    = io_in[8];
    assign io_out[9] = pwm_out;

    // All outputs except [9] are 0, all OEB except [9] are 1 (input/hi-Z)
    genvar g;
    generate
        for (g = 0; g < `MPRJ_IO_PADS; g = g+1) begin : gpio_assign
            if (g == 9) begin
                assign io_oeb[g] = 1'b0;  // output
            end else begin
                assign io_out[g] = 1'b0;
                assign io_oeb[g] = 1'b1;  // input/hi-Z
            end
        end
    endgenerate

    assign la_data_out = 128'b0;
    assign user_irq    = 3'b0;

    // --- Wishbone CSR ---
    wb_csr csr_inst (
        .wb_clk_i   (wb_clk_i),   .wb_rst_i   (wb_rst_i),
        .wbs_stb_i  (wbs_stb_i),  .wbs_cyc_i  (wbs_cyc_i),
        .wbs_we_i   (wbs_we_i),   .wbs_sel_i  (wbs_sel_i),
        .wbs_dat_i  (wbs_dat_i),  .wbs_adr_i  (wbs_adr_i),
        .wbs_ack_o  (wbs_ack_o),  .wbs_dat_o  (wbs_dat_o),
        .enable     (enable),      .bypass_fir (bypass_fir),
        .bypass_cic (bypass_cic), .soft_rst   (soft_rst),
        .osr        (osr),
        .coeff_addr (coeff_addr), .coeff_data (coeff_data),
        .coeff_wr   (coeff_wr),   .pwm_direct (pwm_direct),
        .data_valid (fir_valid),  .overflow   (1'b0)
    );

    // --- CIC Decimator ---
    cic_decimator #(.N_STAGES(3), .WIDTH(16), .OSR_MAX(64)) cic_inst (
        .clk        (wb_clk_i),
        .rst_n      (~(wb_rst_i | soft_rst)),
        .bit_in     (bit_in),
        .osr        (osr),
        .data_out   (cic_out),
        .data_valid (cic_valid)
    );

    // --- FIR Filter ---
    fir_filter #(.N_TAPS(8), .WIDTH(16)) fir_inst (
        .clk        (wb_clk_i),
        .rst_n      (~(wb_rst_i | soft_rst)),
        .data_in    (bypass_cic ? {bit_in, 15'b0} : cic_out),
        .data_valid (bypass_cic ? enable : (cic_valid & enable)),
        .data_out   (fir_out),
        .out_valid  (fir_valid),
        .coeff_addr (coeff_addr),
        .coeff_data (coeff_data),
        .coeff_wr   (coeff_wr)
    );

    // --- PWM DAC ---
    pwm_dac #(.WIDTH(8)) pwm_inst (
        .clk      (wb_clk_i),
        .rst_n    (~(wb_rst_i | soft_rst)),
        .data_in  (bypass_fir ? pwm_direct : fir_out[15:8]),
        .enable   (enable),
        .pwm_out  (pwm_out)
    );

endmodule
`default_nettype wire
