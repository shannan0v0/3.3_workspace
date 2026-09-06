`timescale 1ns/1ps
// AX7020 ANC top-level wrapper. Connect this module to the Zynq PS bus bridge
// or an AXI-lite adapter in the Vivado block design.
module anc_top (
    input  logic                   sys_clk,
    input  logic                   rst,
    input  logic                   i2s_bclk,
    input  logic                   i2s_lrclk,
    input  logic                   i2s_sdin,
    output logic                   i2s_sdout,
    input  logic                   bus_valid,
    input  logic                   bus_write,
    input  logic        [11:0]     bus_addr,
    input  logic        [31:0]     bus_wdata,
    output logic        [31:0]     bus_rdata,
    output logic                   bus_rvalid,
    output logic                   bus_ready,
    output logic                   audio_sample_valid,
    output logic signed [23:0]     anti_noise_sample,
    output logic signed [23:0]     residual_sample,
    output logic        [31:0]     status_sample_count,
    output logic        [31:0]     status_clip_count
);

    logic signed [23:0] ref_sample;
    logic signed [23:0] error_sample;
    logic signed [23:0] tx_right_sample;
    logic               i2s_sample_valid;
    logic               cfg_enable;
    logic               cfg_bypass;
    logic        [15:0] cfg_mu_q15;
    logic               coeff_wr_en;
    logic        [6:0]  coeff_wr_addr;
    logic signed [15:0] coeff_wr_data;

    anc_i2s_if u_i2s (
        .clk(sys_clk),
        .rst(rst),
        .i2s_bclk(i2s_bclk),
        .i2s_lrclk(i2s_lrclk),
        .i2s_sdin(i2s_sdin),
        .i2s_sdout(i2s_sdout),
        .ref_sample(ref_sample),
        .error_sample(error_sample),
        .sample_valid(i2s_sample_valid),
        .tx_left_sample(anti_noise_sample),
        .tx_right_sample(tx_right_sample)
    );

    anc_fx_lms_core #(.TAPS(128)) u_core (
        .clk(sys_clk),
        .rst(rst),
        .sample_valid(i2s_sample_valid),
        .enable(cfg_enable),
        .bypass(cfg_bypass),
        .ref_sample(ref_sample),
        .error_sample(error_sample),
        .mu_q15(cfg_mu_q15),
        .coeff_wr_en(coeff_wr_en),
        .coeff_wr_addr(coeff_wr_addr),
        .coeff_wr_data(coeff_wr_data),
        .sample_out_valid(audio_sample_valid),
        .anti_noise_sample(anti_noise_sample),
        .residual_sample(residual_sample),
        .sample_count(status_sample_count),
        .clip_count(status_clip_count)
    );

    assign tx_right_sample = residual_sample;

    anc_reg_bank u_regs (
        .clk(sys_clk),
        .rst(rst),
        .bus_valid(bus_valid),
        .bus_write(bus_write),
        .bus_addr(bus_addr),
        .bus_wdata(bus_wdata),
        .bus_rdata(bus_rdata),
        .bus_rvalid(bus_rvalid),
        .bus_ready(bus_ready),
        .enable(cfg_enable),
        .bypass(cfg_bypass),
        .mu_q15(cfg_mu_q15),
        .coeff_wr_en(coeff_wr_en),
        .coeff_wr_addr(coeff_wr_addr),
        .coeff_wr_data(coeff_wr_data),
        .sample_count(status_sample_count),
        .clip_count(status_clip_count),
        .anti_noise_sample(anti_noise_sample),
        .residual_sample(residual_sample)
    );
endmodule
