`timescale 1ns/1ps
// Independent, resource-controlled time-multiplexed FxLMS core.
//
// The default and supported configuration is exactly 128 taps. One shared
// 40x40 signed multiplier is used by the FIR, gradient, and coefficient
// update phases. The secondary path is the bounded identity approximation.
// This module is intentionally not instantiated by anc_top: it is an
// additive alternative to anc_fx_lms_core for offline resource experiments.
module anc_fx_lms_tm_core #(
    parameter integer TAPS = 128
) (
    input  logic                   clk,
    input  logic                   rst,
    input  logic                   sample_valid,
    input  logic                   enable,
    input  logic                   bypass,
    input  logic signed [23:0]     ref_sample,
    input  logic signed [23:0]     error_sample,
    input  logic signed [15:0]     mu_q15,
    input  logic                   coeff_wr_en,
    input  logic        [6:0]      coeff_wr_addr,
    input  logic signed [15:0]     coeff_wr_data,
    output logic                   sample_ready,
    output logic                   coeff_wr_ready,
    output logic                   busy,
    output logic                   overrun,
    output logic        [31:0]     overrun_count,
    output logic                   sample_out_valid,
    output logic signed [23:0]     anti_noise_sample,
    output logic signed [23:0]     residual_sample,
    output logic        [31:0]     sample_count,
    output logic        [31:0]     clip_count
);

    // The interface is deliberately fixed at the 128-tap boundary. TAPS is
    // retained for array sizing and reset/update loops; use TAPS=128 only.
    localparam logic [6:0] LAST_TAP = 7'd127;
    localparam logic [2:0] ST_IDLE  = 3'd0;
    localparam logic [2:0] ST_FIR   = 3'd1;
    localparam logic [2:0] ST_GRAD  = 3'd2;
    localparam logic [2:0] ST_DELTA = 3'd3;

    logic [2:0] state;
    logic [6:0] tap_index;
    logic [6:0] write_ptr;
    logic [6:0] sample_ptr;
    logic signed [15:0] coeff [0:TAPS-1];
    logic signed [23:0] x_hist [0:TAPS-1];

    logic signed [23:0] ref_reg;
    logic signed [23:0] error_reg;
    logic signed [15:0] mu_reg;
    logic signed [39:0] gradient_q15;
    logic signed [79:0] fir_acc;

    // One explicit multiplier datapath. All operands are sign-extended to
    // the same 40-bit signed width before multiplication. The product is
    // retained at 80 bits before the fixed-point shifts.
    logic signed [23:0] tap_value;
    logic signed [39:0] multiplier_a;
    logic signed [39:0] multiplier_b;
    logic signed [79:0] multiplier_result;
    logic signed [79:0] fir_acc_next;
    logic signed [79:0] fir_output_wide;
    logic signed [39:0] gradient_next;
    logic signed [79:0] coeff_ext_wide;
    logic signed [79:0] delta_ext_wide;
    logic signed [79:0] coeff_sum_wide;

    integer reset_index;

    function automatic logic signed [23:0] sat24(input logic signed [79:0] value);
        begin
            if (value > 80'sd8388607)
                sat24 = 24'sh7fffff;
            else if (value < -80'sd8388608)
                sat24 = -24'sd8388608;
            else
                sat24 = value[23:0];
        end
    endfunction

    function automatic logic signed [15:0] sat16(input logic signed [79:0] value);
        begin
            if (value > 80'sd32767)
                sat16 = 16'sh7fff;
            else if (value < -80'sd32768)
                sat16 = -16'sd32768;
            else
                sat16 = value[15:0];
        end
    endfunction

    function automatic logic [31:0] inc_sat32(input logic [31:0] value);
        begin
            if (value == 32'hffffffff)
                inc_sat32 = value;
            else
                inc_sat32 = value + 32'd1;
        end
    endfunction

    // For 128 taps, subtraction in seven bits is modulo 128. tap 0 is the
    // just-captured sample; the other taps address the circular history.
    always_comb begin
        if (tap_index == 7'd0)
            tap_value = ref_reg;
        else
            tap_value = x_hist[sample_ptr - tap_index];
    end

    always_comb begin
        sample_ready  = (state == ST_IDLE) && !rst;
        coeff_wr_ready = sample_ready;
        busy          = (state != ST_IDLE) && !rst;
    end

    // State-selected operands keep one syntactic multiplier for all phases.
    always_comb begin
        multiplier_a = 40'sd0;
        multiplier_b = 40'sd0;
        case (state)
            ST_FIR: begin
                multiplier_a = $signed({{24{coeff[tap_index][15]}},
                                        coeff[tap_index]});
                multiplier_b = $signed({{16{tap_value[23]}}, tap_value});
            end
            ST_GRAD: begin
                multiplier_a = $signed({{24{mu_reg[15]}}, mu_reg});
                multiplier_b = $signed({{16{error_reg[23]}}, error_reg});
            end
            ST_DELTA: begin
                multiplier_a = gradient_q15;
                multiplier_b = $signed({{16{tap_value[23]}}, tap_value});
            end
            default: begin
                multiplier_a = 40'sd0;
                multiplier_b = 40'sd0;
            end
        endcase
    end

    assign multiplier_result = multiplier_a * multiplier_b;
    assign fir_acc_next = fir_acc + multiplier_result;
    // Coefficient and sample containers both carry 15 fractional bits.
    assign fir_output_wide = fir_acc_next >>> 15;
    // The gradient is rounded toward negative infinity by arithmetic shift;
    // this is deterministic and is part of the fixed-point contract.
    assign gradient_next = $signed(multiplier_result) >>> 15;
    // (gradient(Q15) * x(Q15)) >> 15 returns a Q15 coefficient delta.
    // Sign extension is explicit on both addends; no unsigned concatenation
    // participates in the coefficient update expression.
    assign coeff_ext_wide = $signed({{64{coeff[tap_index][15]}},
                                     coeff[tap_index]});
    assign delta_ext_wide = $signed(multiplier_result) >>> 15;
    assign coeff_sum_wide = coeff_ext_wide + delta_ext_wide;

    always_ff @(posedge clk) begin
        if (rst) begin
            state              <= ST_IDLE;
            tap_index          <= 7'd0;
            write_ptr          <= 7'd0;
            sample_ptr         <= 7'd0;
            ref_reg            <= 24'sd0;
            error_reg          <= 24'sd0;
            mu_reg             <= 16'sd0;
            gradient_q15       <= 40'sd0;
            fir_acc            <= 80'sd0;
            sample_out_valid   <= 1'b0;
            anti_noise_sample  <= 24'sd0;
            residual_sample    <= 24'sd0;
            sample_count       <= 32'd0;
            clip_count         <= 32'd0;
            overrun            <= 1'b0;
            overrun_count      <= 32'd0;
            for (reset_index = 0; reset_index < TAPS; reset_index = reset_index + 1) begin
                coeff[reset_index] <= 16'sd0;
                x_hist[reset_index] <= 24'sd0;
            end
        end else begin
            sample_out_valid <= 1'b0;

            // sample_valid is a pulse-oriented request. A request observed
            // while busy is dropped, counted, and latches overrun.
            if ((state != ST_IDLE) && sample_valid) begin
                overrun       <= 1'b1;
                overrun_count <= inc_sat32(overrun_count);
            end

            // Coefficient writes are accepted only in idle. A simultaneous
            // accepted sample is legal; the write is visible to the first FIR
            // tap because FIR starts on the following clock.
            if (coeff_wr_en && coeff_wr_ready)
                coeff[coeff_wr_addr] <= coeff_wr_data;

            case (state)
                ST_IDLE: begin
                    if (sample_valid) begin
                        ref_reg    <= ref_sample;
                        error_reg  <= error_sample;
                        mu_reg     <= mu_q15;
                        sample_ptr <= write_ptr;
                        x_hist[write_ptr] <= ref_sample;
                        if (write_ptr == LAST_TAP)
                            write_ptr <= 7'd0;
                        else
                            write_ptr <= write_ptr + 7'd1;
                        sample_count <= inc_sat32(sample_count);

                        if (bypass) begin
                            anti_noise_sample <= ref_sample;
                            residual_sample   <= error_sample;
                            sample_out_valid  <= 1'b1;
                        end else if (!enable) begin
                            // Disabled and non-bypass is a safe muted output.
                            anti_noise_sample <= 24'sd0;
                            residual_sample   <= error_sample;
                            sample_out_valid  <= 1'b1;
                        end else begin
                            fir_acc   <= 80'sd0;
                            tap_index <= 7'd0;
                            state     <= ST_FIR;
                        end
                    end
                end

                ST_FIR: begin
                    if (tap_index == LAST_TAP) begin
                        anti_noise_sample <= sat24(fir_output_wide);
                        residual_sample   <= error_reg;
                        sample_out_valid  <= 1'b1;
                        if ((fir_output_wide > 80'sd8388607) ||
                            (fir_output_wide < -80'sd8388608))
                            clip_count <= inc_sat32(clip_count);
                        tap_index <= 7'd0;
                        state     <= ST_GRAD;
                    end else begin
                        fir_acc   <= fir_acc_next;
                        tap_index <= tap_index + 7'd1;
                    end
                end

                ST_GRAD: begin
                    gradient_q15 <= gradient_next;
                    tap_index     <= 7'd0;
                    state         <= ST_DELTA;
                end

                ST_DELTA: begin
                    if (enable && !bypass)
                        coeff[tap_index] <= sat16(coeff_sum_wide);
                    if (tap_index == LAST_TAP) begin
                        state <= ST_IDLE;
                    end else begin
                        tap_index <= tap_index + 7'd1;
                    end
                end

                default: begin
                    state <= ST_IDLE;
                end
            endcase
        end
    end
endmodule
