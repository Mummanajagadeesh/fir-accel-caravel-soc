// Wishbone CSR Block
// Register map (32-bit word addresses):
// 0x00 - CTRL      [0]=enable, [1]=bypass_fir, [2]=bypass_cic, [3]=soft_rst
// 0x01 - OSR       [6:0]=decimation ratio (8/16/32/64)
// 0x02 - COEFF_ADDR [2:0]=tap index (0-7)
// 0x03 - COEFF_DATA [15:0]=Q1.15 coefficient value
// 0x04 - STATUS    [0]=data_valid, [1]=overflow (read-only)
// 0x05 - PWM_DATA  [7:0]=direct PWM input (bypass mode)

module wb_csr #(
    parameter BASE_ADDR = 32'h3000_0000
)(
    input  wire         wb_clk_i,
    input  wire         wb_rst_i,
    // Wishbone slave interface
    input  wire         wbs_stb_i,
    input  wire         wbs_cyc_i,
    input  wire         wbs_we_i,
    input  wire [3:0]   wbs_sel_i,
    input  wire [31:0]  wbs_dat_i,
    input  wire [31:0]  wbs_adr_i,
    output reg          wbs_ack_o,
    output reg  [31:0]  wbs_dat_o,
    // Control outputs to datapath
    output reg          enable,
    output reg          bypass_fir,
    output reg          bypass_cic,
    output reg          soft_rst,
    output reg  [6:0]   osr,
    output reg  [2:0]   coeff_addr,
    output reg  [15:0]  coeff_data,
    output reg          coeff_wr,
    output reg  [7:0]   pwm_direct,
    // Status inputs from datapath
    input  wire         data_valid,
    input  wire         overflow
);

    // Internal registers
    reg [31:0] reg_ctrl;
    reg [31:0] reg_osr;
    reg [31:0] reg_coeff_addr;
    reg [31:0] reg_coeff_data;
    reg [31:0] reg_pwm_data;

    wire wb_valid = wbs_stb_i && wbs_cyc_i;
    wire [4:0] addr_offset = wbs_adr_i[6:2]; // word index

    // Wishbone transactions
    always @(posedge wb_clk_i or posedge wb_rst_i) begin
        if (wb_rst_i) begin
            wbs_ack_o     <= 0;
            wbs_dat_o     <= 0;
            reg_ctrl      <= 32'h0000_0001; // enable=1 by default
            reg_osr       <= 32'h0000_0010; // OSR=16 by default
            reg_coeff_addr<= 0;
            reg_coeff_data<= 0;
            reg_pwm_data  <= 32'h0000_0080; // midpoint
            coeff_wr      <= 0;
        end else begin
            wbs_ack_o <= 0;
            coeff_wr  <= 0;

            if (wb_valid && !wbs_ack_o) begin
                wbs_ack_o <= 1;

                if (wbs_we_i) begin
                    // Write
                    case (addr_offset)
                        5'h00: reg_ctrl       <= wbs_dat_i;
                        5'h01: reg_osr        <= wbs_dat_i;
                        5'h02: reg_coeff_addr <= wbs_dat_i;
                        5'h03: begin
                               reg_coeff_data <= wbs_dat_i;
                               coeff_wr       <= 1;  // pulse on coeff write
                               end
                        5'h05: reg_pwm_data   <= wbs_dat_i;
                        default: ;
                    endcase
                end else begin
                    // Read
                    case (addr_offset)
                        5'h00: wbs_dat_o <= reg_ctrl;
                        5'h01: wbs_dat_o <= reg_osr;
                        5'h02: wbs_dat_o <= reg_coeff_addr;
                        5'h03: wbs_dat_o <= reg_coeff_data;
                        5'h04: wbs_dat_o <= {30'b0, overflow, data_valid};
                        5'h05: wbs_dat_o <= reg_pwm_data;
                        default: wbs_dat_o <= 32'hDEAD_BEEF;
                    endcase
                end
            end
        end
    end

    // Drive outputs from registers
    always @(*) begin
        enable     = reg_ctrl[0];
        bypass_fir = reg_ctrl[1];
        bypass_cic = reg_ctrl[2];
        soft_rst   = reg_ctrl[3];
        osr        = reg_osr[6:0];
        coeff_addr = reg_coeff_addr[2:0];
        coeff_data = reg_coeff_data[15:0];
        pwm_direct = reg_pwm_data[7:0];
    end

endmodule
