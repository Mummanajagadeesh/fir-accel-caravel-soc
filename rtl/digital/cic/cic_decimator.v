module cic_decimator #(
    parameter N_STAGES  = 3,
    parameter WIDTH     = 16,
    parameter OSR_MAX   = 64
)(
    input  wire             clk,
    input  wire             rst_n,
    input  wire             bit_in,
    input  wire [6:0]       osr,
    output reg  [WIDTH-1:0] data_out,
    output reg              data_valid
);

    wire signed [WIDTH-1:0] x_in = bit_in ? {{(WIDTH-1){1'b0}}, 1'b1}
                                           : {WIDTH{1'b0}};

    // --- INTEGRATORS (high rate) ---
    reg signed [WIDTH-1:0] integrator [0:N_STAGES-1];
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < N_STAGES; i = i+1)
                integrator[i] <= 0;
        end else begin
            integrator[0] <= integrator[0] + x_in;
            for (i = 1; i < N_STAGES; i = i+1)
                integrator[i] <= integrator[i] + integrator[i-1];
        end
    end

    // --- DECIMATION COUNTER ---
    reg [6:0] dec_counter;
    reg       dec_pulse;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dec_counter <= 0;
            dec_pulse   <= 0;
        end else begin
            if (dec_counter >= osr - 1) begin
                dec_counter <= 0;
                dec_pulse   <= 1;
            end else begin
                dec_counter <= dec_counter + 1;
                dec_pulse   <= 0;
            end
        end
    end

    // --- COMB STAGES (low rate) ---
    // Each stage: out = in - in_delayed (diff by 1 decimated sample)
    // Pipeline: sample integrator output → stage 0 → stage 1 → stage 2
    reg signed [WIDTH-1:0] comb_reg  [0:N_STAGES];    // comb stage inputs
    reg signed [WIDTH-1:0] comb_dly  [0:N_STAGES-1];  // delay registers

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i <= N_STAGES; i = i+1)
                comb_reg[i] <= 0;
            for (i = 0; i < N_STAGES; i = i+1)
                comb_dly[i] <= 0;
            data_out   <= 0;
            data_valid <= 0;
        end else if (dec_pulse) begin
            // Latch integrator output into comb pipeline input
            comb_reg[0] <= integrator[N_STAGES-1];

            // Each comb stage: difference with previous sample
            for (i = 0; i < N_STAGES; i = i+1) begin
                comb_dly[i]   <= comb_reg[i];               // delay register
                comb_reg[i+1] <= comb_reg[i] - comb_dly[i]; // differentiate
            end

            data_out   <= comb_reg[N_STAGES];
            data_valid <= 1;
        end else begin
            data_valid <= 0;
        end
    end

endmodule
