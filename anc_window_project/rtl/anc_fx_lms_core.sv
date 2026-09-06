`timescale 1ns/1ps
// Q15 fixed-point ANC/FxLMS MVP.
// Audio samples are signed 24-bit values with 15 fractional bits.
// The secondary path is intentionally identity in this bounded MVP; replace
// tap_value with the measured secondary-path FIR for the board implementation.
module anc_fx_lms_core #(
    parameter integer TAPS = 128
) (
    input  logic                   clk,
    input  logic                   rst,
    input  logic                   sample_valid,
    input  logic                   enable,
    input  logic                   bypass,
    input  logic signed [23:0]     ref_sample,
    input  logic signed [23:0]     error_sample,
    input  logic        [15:0]     mu_q15,
    input  logic                   coeff_wr_en,
    input  logic        [6:0]      coeff_wr_addr,
    input  logic signed [15:0]     coeff_wr_data,
    output logic                   sample_out_valid,
    output logic signed [23:0]     anti_noise_sample,
    output logic signed [23:0]     residual_sample,
    output logic        [31:0]     sample_count,
    output logic        [31:0]     clip_count
);

    logic signed [15:0] coeff [0:TAPS-1];
    logic signed [23:0] x_delay [0:TAPS-1];
    integer i;

    logic signed [63:0] mac_acc;
    logic signed [63:0] tap_ext;
    logic signed [63:0] coeff_ext;
    logic signed [63:0] update_acc;
    logic signed [63:0] coeff_acc;
    logic signed [63:0] y_wide;
    logic signed [23:0] y_sat;
    logic signed [15:0] coeff_next;

    function automatic signed [23:0] sat24(input logic signed [63:0] value);
        begin
            if (value > 64'sd8388607)
                sat24 = 24'sh7fffff;
            else if (value < -64'sd8388608)
                sat24 = -24'sd8388608;
            else
                sat24 = value[23:0];
        end
    endfunction

    function automatic signed [15:0] sat16(input logic signed [63:0] value);
        begin
            if (value > 64'sd32767)
                sat16 = 16'sh7fff;
            else if (value < -64'sd32768)
                sat16 = -16'sd32768;
            else
                sat16 = value[15:0];
        end
    endfunction

    always_ff @(posedge clk) begin
        if (rst) begin
            sample_out_valid  <= 1'b0;
            anti_noise_sample <= 24'sd0;
            residual_sample   <= 24'sd0;
            sample_count      <= 32'd0;
            clip_count        <= 32'd0;
            mac_acc           = 64'sd0;
            tap_ext           = 64'sd0;
            coeff_ext         = 64'sd0;
            update_acc        = 64'sd0;
            coeff_acc         = 64'sd0;
            y_wide            = 64'sd0;
            y_sat             = 24'sd0;
            coeff_next        = 16'sd0;
            for (i = 0; i < TAPS; i = i + 1) begin
                coeff[i]   <= 16'sd0;
                x_delay[i] <= 24'sd0;
            end
        end else begin
            sample_out_valid <= 1'b0;

            if (coeff_wr_en)
                coeff[coeff_wr_addr] <= coeff_wr_data;

            if (sample_valid) begin
                // FIR output: current reference is tap zero, old history follows.
                tap_ext   = {{40{ref_sample[23]}}, ref_sample};
                coeff_ext = {{48{coeff[0][15]}}, coeff[0]};
                mac_acc   = tap_ext * coeff_ext;
                for (i = 1; i < TAPS; i = i + 1) begin
                    tap_ext   = {{40{x_delay[i-1][23]}}, x_delay[i-1]};
                    coeff_ext = {{48{coeff[i][15]}}, coeff[i]};
                    mac_acc   = mac_acc + (tap_ext * coeff_ext);
                end
                y_wide = mac_acc >>> 15;
                y_sat  = sat24(y_wide);

                // Bypass is deterministic and permits an A/B comparison without a plant.
                if (bypass || !enable)
                    anti_noise_sample <= ref_sample;
                else
                    anti_noise_sample <= y_sat;
                residual_sample <= error_sample;
                sample_out_valid <= 1'b1;
                sample_count <= sample_count + 32'd1;

                if ((y_wide > 64'sd8388607) || (y_wide < -64'sd8388608))
                    clip_count <= clip_count + 32'd1;

                // FxLMS update.  The MVP uses the identity secondary path.
                // mu(Q15)*error(Q15)*x(Q15) is shifted by 30 back to Q15.
                if (enable && !bypass) begin
                    for (i = 0; i < TAPS; i = i + 1) begin
                        if (i == 0)
                            tap_ext = {{40{ref_sample[23]}}, ref_sample};
                        else
                            tap_ext = {{40{x_delay[i-1][23]}}, x_delay[i-1]};
                        update_acc = {{48{mu_q15[15]}}, mu_q15};
                        update_acc = update_acc * {{40{error_sample[23]}}, error_sample};
                        update_acc = update_acc * tap_ext;
                        // Keep both operands signed 64-bit before the Q15 update add.
                        // A bare concatenation is unsigned and can corrupt negative updates.
                        coeff_ext = {{48{coeff[i][15]}}, coeff[i]};
                        coeff_acc = coeff_ext + (update_acc >>> 30);
                        coeff_next = sat16(coeff_acc);
                        coeff[i] <= coeff_next;
                    end
                end

                for (i = TAPS-1; i > 0; i = i - 1)
                    x_delay[i] <= x_delay[i-1];
                x_delay[0] <= ref_sample;
            end
        end
    end
endmodule
