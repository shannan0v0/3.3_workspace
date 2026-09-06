`timescale 1ns/1ps
module tb_anc_fx_lms_core;
    logic clk = 1'b0;
    always #5 clk = ~clk;
    logic rst, sample_valid, enable, bypass;
    logic signed [23:0] ref_sample, error_sample;
    logic [15:0] mu_q15;
    logic coeff_wr_en;
    logic [6:0] coeff_wr_addr;
    logic signed [15:0] coeff_wr_data;
    logic sample_out_valid;
    logic signed [23:0] anti_noise_sample, residual_sample;
    logic [31:0] sample_count, clip_count;
    integer fails;

    anc_fx_lms_core dut (
        .clk(clk), .rst(rst), .sample_valid(sample_valid),
        .enable(enable), .bypass(bypass), .ref_sample(ref_sample),
        .error_sample(error_sample), .mu_q15(mu_q15),
        .coeff_wr_en(coeff_wr_en), .coeff_wr_addr(coeff_wr_addr),
        .coeff_wr_data(coeff_wr_data), .sample_out_valid(sample_out_valid),
        .anti_noise_sample(anti_noise_sample), .residual_sample(residual_sample),
        .sample_count(sample_count), .clip_count(clip_count)
    );

    task automatic reset_core;
        begin
            rst = 1'b1; sample_valid = 1'b0; coeff_wr_en = 1'b0;
            repeat (2) @(posedge clk);
            @(negedge clk); rst = 1'b0;
        end
    endtask

    task automatic write_coeff(input [6:0] addr, input signed [15:0] data);
        begin
            @(negedge clk); coeff_wr_addr = addr; coeff_wr_data = data;
            coeff_wr_en = 1'b1;
            @(negedge clk); coeff_wr_en = 1'b0;
        end
    endtask

    task automatic sample_and_check(input integer r, input integer e,
                                     input integer expected, input [127:0] label);
        begin
            @(negedge clk);
            ref_sample = r; error_sample = e; sample_valid = 1'b1;
            @(posedge clk); #1;
            if (!sample_out_valid) begin
                $display("FAIL %0s: missing valid", label); fails = fails + 1;
            end
            if ($signed(anti_noise_sample) != expected) begin
                $display("FAIL %0s: got %0d expected %0d", label,
                         $signed(anti_noise_sample), expected); fails = fails + 1;
            end
            @(negedge clk); sample_valid = 1'b0;
        end
    endtask

    initial begin
        fails = 0; rst = 1'b0; sample_valid = 1'b0; enable = 1'b0;
        bypass = 1'b1; ref_sample = 0; error_sample = 0; mu_q15 = 16'd64;
        coeff_wr_en = 1'b0; coeff_wr_addr = 0; coeff_wr_data = 0;

        reset_core();
        sample_and_check(12345, 0, 12345, "disabled_bypass");
        if (sample_count !== 32'd1) begin
            $display("FAIL disabled count"); fails = fails + 1;
        end

        enable = 1'b1; bypass = 1'b1;
        sample_and_check(-3210, 0, -3210, "explicit_bypass");

        bypass = 1'b0;
        sample_and_check(111, 0, 0, "zero_fir");
        write_coeff(7'd0, 16'sd16384);
        sample_and_check(1000, 0, 500, "half_gain_fir");

        reset_core(); enable = 1'b1; bypass = 1'b0; mu_q15 = 16'd16384;
        sample_and_check(32768, 32768, 0, "lms_first");
        sample_and_check(32768, 0, 16384, "lms_updated_output");

        // Regression for the adversarial signed-update quadrant found by audit.
        reset_core(); enable = 1'b1; bypass = 1'b0; mu_q15 = 16'd32767;
        sample_and_check(32768, -32768, 0, "lms_negative_update");
        if ($signed(dut.coeff[0]) !== -16'sd32767) begin
            $display("FAIL lms negative coefficient: got %0d expected -32767",
                     $signed(dut.coeff[0]));
            fails = fails + 1;
        end

        reset_core(); enable = 1'b1; bypass = 1'b0; mu_q15 = 16'd0;
        write_coeff(7'd0, 16'sd32767);
        write_coeff(7'd1, 16'sd32767);
        sample_and_check(8388607, 0, 8388351, "near_limit");
        sample_and_check(8388607, 0, 8388607, "saturated_limit");
        if (clip_count !== 32'd1) begin
            $display("FAIL clip count: got %0d expected 1", clip_count);
            fails = fails + 1;
        end

        if (fails == 0) $display("TB_CORE_PASS");
        else $fatal(1, "TB_CORE_FAIL count=%0d", fails);
        $finish;
    end
endmodule
