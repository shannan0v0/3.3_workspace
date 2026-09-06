`timescale 1ns/1ps
module tb_anc_fx_lms_tm_core;
    logic clk = 1'b0;
    always #5 clk = ~clk;

    logic rst;
    logic sample_valid;
    logic enable;
    logic bypass;
    logic signed [23:0] ref_sample;
    logic signed [23:0] error_sample;
    logic signed [15:0] mu_q15;
    logic coeff_wr_en;
    logic [6:0] coeff_wr_addr;
    logic signed [15:0] coeff_wr_data;

    logic sample_ready;
    logic coeff_wr_ready;
    logic busy;
    logic overrun;
    logic [31:0] overrun_count;
    logic sample_out_valid;
    logic signed [23:0] anti_noise_sample;
    logic signed [23:0] residual_sample;
    logic [31:0] sample_count;
    logic [31:0] clip_count;
    integer fails;
    integer cycles;

    anc_fx_lms_tm_core #(.TAPS(128)) dut (
        .clk(clk), .rst(rst), .sample_valid(sample_valid),
        .enable(enable), .bypass(bypass), .ref_sample(ref_sample),
        .error_sample(error_sample), .mu_q15(mu_q15),
        .coeff_wr_en(coeff_wr_en), .coeff_wr_addr(coeff_wr_addr),
        .coeff_wr_data(coeff_wr_data), .sample_ready(sample_ready),
        .coeff_wr_ready(coeff_wr_ready), .busy(busy), .overrun(overrun),
        .overrun_count(overrun_count), .sample_out_valid(sample_out_valid),
        .anti_noise_sample(anti_noise_sample),
        .residual_sample(residual_sample), .sample_count(sample_count),
        .clip_count(clip_count)
    );

    task automatic reset_core;
        begin
            rst = 1'b1;
            sample_valid = 1'b0;
            coeff_wr_en = 1'b0;
            repeat (2) @(posedge clk);
            @(negedge clk);
            rst = 1'b0;
            #1; // allow combinational ready/busy outputs to settle
        end
    endtask

    task automatic write_coeff(input [6:0] addr, input signed [15:0] data);
        begin
            @(negedge clk);
            if (!coeff_wr_ready) begin
                $display("FAIL coefficient write not ready at idle");
                fails = fails + 1;
            end
            coeff_wr_addr = addr;
            coeff_wr_data = data;
            coeff_wr_en = 1'b1;
            @(posedge clk);
            @(negedge clk);
            coeff_wr_en = 1'b0;
        end
    endtask

    task automatic send_sample(input integer r, input integer e);
        begin
            @(negedge clk);
            ref_sample = r;
            error_sample = e;
            sample_valid = 1'b1;
            @(posedge clk);
            @(negedge clk);
            sample_valid = 1'b0;
        end
    endtask

    task automatic wait_output(input integer max_cycles, input integer expected,
                               input [127:0] label);
        begin
            cycles = 0;
            while (!sample_out_valid && cycles < max_cycles) begin
                @(posedge clk);
                #1;
                cycles = cycles + 1;
            end
            if (!sample_out_valid) begin
                $display("FAIL %0s: output timeout", label);
                fails = fails + 1;
            end else if ($signed(anti_noise_sample) !== expected) begin
                $display("FAIL %0s: got %0d expected %0d", label,
                         $signed(anti_noise_sample), expected);
                fails = fails + 1;
            end
        end
    endtask

    initial begin
        fails = 0;
        rst = 1'b0;
        sample_valid = 1'b0;
        enable = 1'b0;
        bypass = 1'b1;
        ref_sample = 0;
        error_sample = 0;
        mu_q15 = 16'sd0;
        coeff_wr_en = 1'b0;
        coeff_wr_addr = 0;
        coeff_wr_data = 0;

        reset_core();
        if (!sample_ready || busy || !coeff_wr_ready) begin
            $display("FAIL idle handshake after reset");
            fails = fails + 1;
        end

        // Bypass is immediate, accepts one sample per clock, and updates the
        // history without entering the long processing schedule.
        send_sample(12345, -77);
        #1; // send_sample ends at the negedge after the accepting edge
        if (!sample_out_valid || $signed(anti_noise_sample) !== 12345 || busy) begin
            $display("FAIL bypass behavior");
            fails = fails + 1;
        end

        // FIR phase: one nonzero coefficient gives a half-gain result.
        reset_core();
        enable = 1'b1;
        bypass = 1'b0;
        mu_q15 = 16'sd0;
        write_coeff(7'd0, 16'sd16384);
        send_sample(1000, 9);
        if (!busy || sample_ready) begin
            $display("FAIL busy/ready assertion after accept");
            fails = fails + 1;
        end
        wait_output(140, 500, "half_gain");
        if (sample_count !== 32'd1 || $signed(residual_sample) !== 9) begin
            $display("FAIL output metadata");
            fails = fails + 1;
        end
        while (busy) @(posedge clk);
        if (overrun) begin
            $display("FAIL unexpected overrun");
            fails = fails + 1;
        end

        // Negative signed update probe: +mu * negative error * positive x.
        reset_core();
        enable = 1'b1;
        bypass = 1'b0;
        mu_q15 = 16'sd32767;
        send_sample(32768, -32768);
        wait_output(140, 0, "negative_update_output");
        while (busy) @(posedge clk);
        if ($signed(dut.coeff[0]) !== -16'sd32767) begin
            $display("FAIL negative update coefficient: got %0d expected -32767",
                     $signed(dut.coeff[0]));
            fails = fails + 1;
        end

        // Tap-127 write proves the complete 128-entry boundary is reachable.
        reset_core();
        write_coeff(7'd127, 16'sd1234);
        if ($signed(dut.coeff[127]) !== 16'sd1234) begin
            $display("FAIL coefficient address 127");
            fails = fails + 1;
        end

        // A request during the serialized operation is dropped and latches
        // overrun; it must not corrupt the accepted sample count.
        enable = 1'b1;
        bypass = 1'b0;
        mu_q15 = 16'sd0;
        send_sample(1, 0);
        @(negedge clk);
        ref_sample = 2;
        error_sample = 0;
        sample_valid = 1'b1;
        @(posedge clk); #1;
        @(negedge clk); sample_valid = 1'b0;
        if (!overrun || overrun_count == 0) begin
            $display("FAIL overrun semantics");
            fails = fails + 1;
        end
        wait_output(140, 0, "overrun_sample");
        while (busy) @(posedge clk);
        if (sample_count !== 32'd1) begin
            $display("FAIL overrun changed sample count");
            fails = fails + 1;
        end

        // Output and coefficient arithmetic are bounded by saturation.
        reset_core();
        enable = 1'b1;
        bypass = 1'b0;
        mu_q15 = 16'sd0;
        write_coeff(7'd0, 16'sd32767);
        write_coeff(7'd1, 16'sd32767);
        send_sample(8388607, 0);
        wait_output(140, 8388351, "near_limit");
        while (busy) @(posedge clk);
        send_sample(8388607, 0);
        wait_output(140, 8388607, "saturated_output");
        if (clip_count !== 32'd1) begin
            $display("FAIL clip count: got %0d expected 1", clip_count);
            fails = fails + 1;
        end

        if (fails == 0)
            $display("TB_TM_CORE_PASS");
        else
            $fatal(1, "TB_TM_CORE_FAIL count=%0d", fails);
        $finish;
    end
endmodule
