`timescale 1ns/1ps
// I2S boundary for a 100 MHz system-clock domain.
// Assumption: 32-bit slots, one leading dummy bit, then 24-bit MSB-first data
// followed by seven pad bits. LRCLK=0 is left/reference and LRCLK=1 is right/error.
// BCLK and LRCLK are synchronized into clk; this is a compact MVP boundary,
// not a substitute for a board-level CDC/timing review.
module anc_i2s_if (
    input  logic                   clk,
    input  logic                   rst,
    input  logic                   i2s_bclk,
    input  logic                   i2s_lrclk,
    input  logic                   i2s_sdin,
    output logic                   i2s_sdout,
    output logic signed [23:0]     ref_sample,
    output logic signed [23:0]     error_sample,
    output logic                   sample_valid,
    input  logic signed [23:0]     tx_left_sample,
    input  logic signed [23:0]     tx_right_sample
);

    logic bclk_meta, bclk_sync, bclk_prev;
    logic lr_meta, lr_sync, lr_prev;
    logic sd_meta, sd_sync;
    logic [5:0] rx_count;
    logic [5:0] tx_count;
    logic [31:0] rx_shift;
    logic [31:0] tx_shift;
    logic signed [23:0] left_reg;
    logic [31:0] rx_word;
    logic [31:0] tx_word;

    always_ff @(posedge clk) begin
        if (rst) begin
            bclk_meta      <= 1'b0;
            bclk_sync      <= 1'b0;
            bclk_prev      <= 1'b0;
            lr_meta        <= 1'b0;
            lr_sync        <= 1'b0;
            lr_prev        <= 1'b0;
            sd_meta        <= 1'b0;
            sd_sync        <= 1'b0;
            rx_count       <= 6'd0;
            tx_count       <= 6'd0;
            rx_shift       <= 32'd0;
            tx_shift       <= 32'd0;
            left_reg       <= 24'sd0;
            rx_word        = 32'd0;
            tx_word        = 32'd0;
            ref_sample     <= 24'sd0;
            error_sample   <= 24'sd0;
            sample_valid   <= 1'b0;
            i2s_sdout      <= 1'b0;
        end else begin
            bclk_meta <= i2s_bclk;
            bclk_sync <= bclk_meta;
            bclk_prev <= bclk_sync;
            lr_meta   <= i2s_lrclk;
            lr_sync   <= lr_meta;
            lr_prev   <= lr_sync;
            sd_meta   <= i2s_sdin;
            sd_sync   <= sd_meta;
            sample_valid <= 1'b0;

            if (lr_sync != lr_prev) begin
                rx_count <= 6'd0;
                tx_count <= 6'd0;
            end

            // Receive on synchronized BCLK rising edge.
            if (bclk_sync && !bclk_prev) begin
                if (rx_count == 6'd31) begin
                    rx_word = {rx_shift[30:0], sd_sync};
                    if (lr_sync == 1'b0) begin
                        left_reg <= rx_word[30:7];
                    end else begin
                        ref_sample   <= left_reg;
                        error_sample <= rx_word[30:7];
                        sample_valid <= 1'b1;
                    end
                    rx_count <= 6'd0;
                    rx_shift <= 32'd0;
                end else begin
                    rx_shift <= {rx_shift[30:0], sd_sync};
                    rx_count <= rx_count + 6'd1;
                end
            end

            // Transmit on synchronized BCLK falling edge.
            if (!bclk_sync && bclk_prev) begin
                if (tx_count == 6'd0) begin
                    if (lr_sync == 1'b0)
                        tx_word = {1'b0, tx_left_sample, 7'b0};
                    else
                        tx_word = {1'b0, tx_right_sample, 7'b0};
                    i2s_sdout <= tx_word[31];
                    tx_shift  <= {tx_word[30:0], 1'b0};
                    tx_count  <= 6'd1;
                end else begin
                    i2s_sdout <= tx_shift[31];
                    tx_shift  <= {tx_shift[30:0], 1'b0};
                    if (tx_count == 6'd31)
                        tx_count <= 6'd0;
                    else
                        tx_count <= tx_count + 6'd1;
                end
            end
        end
    end
endmodule
