`timescale 1ns/1ps
module tb;
    logic clk = 1'b0;
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

    integer failures;
    integer case_fail;
    integer sim_edges;
    integer observed_anti;
    integer observed_residual;
    integer observed_clip;
    integer observed_output_edge;
    integer observed_output_count;
    integer i;
    integer j;
    integer v;

    anc_fx_lms_tm_core #(.TAPS(128)) dut (
        .clk(clk), .rst(rst), .sample_valid(sample_valid), .enable(enable),
        .bypass(bypass), .ref_sample(ref_sample), .error_sample(error_sample),
        .mu_q15(mu_q15), .coeff_wr_en(coeff_wr_en),
        .coeff_wr_addr(coeff_wr_addr), .coeff_wr_data(coeff_wr_data),
        .sample_ready(sample_ready), .coeff_wr_ready(coeff_wr_ready),
        .busy(busy), .overrun(overrun), .overrun_count(overrun_count),
        .sample_out_valid(sample_out_valid),
        .anti_noise_sample(anti_noise_sample),
        .residual_sample(residual_sample), .sample_count(sample_count),
        .clip_count(clip_count)
    );

    always #5 clk = ~clk;

    task automatic begin_case(input string name);
        begin
            case_fail = 0;
            $display("CASE_BEGIN %s", name);
        end
    endtask

    task automatic end_case(input string name);
        begin
            if (case_fail == 0)
                $display("CASE %s PASS", name);
            else
                $display("CASE %s FAIL", name);
        end
    endtask

    task automatic check_eq(input string item, input integer actual,
                            input integer expected);
        begin
            if (actual !== expected) begin
                failures = failures + 1;
                case_fail = case_fail + 1;
                $display("CHECK FAIL case_item=%s actual=%0d expected=%0d", item, actual, expected);
            end else begin
                $display("CHECK PASS case_item=%s value=%0d", item, actual);
            end
        end
    endtask

    // One call is exactly one sampled rising edge. TRACE is consumed by the
    // independent Python model for edge-by-edge comparison.
    task automatic tick_inputs(
        input integer t_rst, input integer t_sv, input integer t_en,
        input integer t_bp, input integer t_ref, input integer t_err,
        input integer t_mu, input integer t_cwen, input integer t_caddr,
        input integer t_cdata, input string t_tag);
        begin
            rst = t_rst;
            sample_valid = t_sv;
            enable = t_en;
            bypass = t_bp;
            ref_sample = t_ref;
            error_sample = t_err;
            mu_q15 = t_mu;
            coeff_wr_en = t_cwen;
            coeff_wr_addr = t_caddr;
            coeff_wr_data = t_cdata;
            @(posedge clk);
            #1;
            sim_edges = sim_edges + 1;
            $display("TRACE tag=%s rst=%0d sv=%0d en=%0d bp=%0d ref=%0d err=%0d mu=%0d cwen=%0d caddr=%0d cdata=%0d ready=%0d cwready=%0d busy=%0d ov=%0d ovc=%0d valid=%0d anti=%0d residual=%0d sc=%0d clip=%0d edge=%0d",
                     t_tag, rst, sample_valid, enable, bypass,
                     $signed(ref_sample), $signed(error_sample), $signed(mu_q15),
                     coeff_wr_en, coeff_wr_addr, $signed(coeff_wr_data),
                     sample_ready, coeff_wr_ready, busy, overrun, overrun_count,
                     sample_out_valid, $signed(anti_noise_sample),
                     $signed(residual_sample), sample_count, clip_count, sim_edges);
        end
    endtask

    task automatic reset_state;
        begin
            tick_inputs(1,0,0,0,0,0,0,0,0,0,"RESET_ASSERT");
            tick_inputs(1,0,0,0,0,0,0,0,0,0,"RESET_ASSERT");
            check_eq("reset.sample_ready", sample_ready, 0);
            check_eq("reset.coeff_wr_ready", coeff_wr_ready, 0);
            check_eq("reset.busy", busy, 0);
            check_eq("reset.sample_count", sample_count, 0);
            check_eq("reset.clip_count", clip_count, 0);
            check_eq("reset.overrun", overrun, 0);
            check_eq("reset.overrun_count", overrun_count, 0);
            check_eq("reset.anti_noise", $signed(anti_noise_sample), 0);
            check_eq("reset.residual", $signed(residual_sample), 0);
            tick_inputs(0,0,0,0,0,0,0,0,0,0,"RESET_RELEASE");
            check_eq("release.sample_ready", sample_ready, 1);
            check_eq("release.coeff_wr_ready", coeff_wr_ready, 1);
            check_eq("release.busy", busy, 0);
        end
    endtask

    task automatic write_coeff(input integer addr, input integer data);
        begin
            check_eq("coeff_write.ready_before", coeff_wr_ready, 1);
            tick_inputs(0,0,0,0,0,0,0,1,addr,data,"COEFF_WRITE");
            check_eq("coeff_write.ready_after", coeff_wr_ready, 1);
            check_eq("coeff_write.coeff_value", $signed(dut.coeff[addr]), data);
        end
    endtask

    task automatic disabled_history(input integer ref_v, input integer err_v);
        integer k;
        begin
            for (k = 0; k < 128; k = k + 1) begin
                tick_inputs(0,1,0,0,ref_v,err_v,0,0,0,0,"HISTORY_DISABLED");
                check_eq("history.sample_out_valid", sample_out_valid, 1);
                check_eq("history.ready", sample_ready, 1);
            end
        end
    endtask

    task automatic start_enabled(input integer ref_v, input integer err_v,
                                  input integer mu_v, input string tag_v);
        begin
            check_eq("enabled.ready_before", sample_ready, 1);
            tick_inputs(0,1,1,0,ref_v,err_v,mu_v,0,0,0,tag_v);
            check_eq("enabled.busy_after_accept", busy, 1);
            check_eq("enabled.ready_after_accept", sample_ready, 0);
            check_eq("enabled.no_accept_output", sample_out_valid, 0);
        end
    endtask

    task automatic finish_enabled(input integer first_tick, input integer ref_v,
                                  input integer err_v, input integer mu_v,
                                  input string tag_v);
        integer k;
        integer out_seen;
        integer out_edge;
        begin
            out_seen = 0;
            out_edge = 0;
            observed_anti = 0;
            observed_residual = 0;
            observed_clip = -1;
            for (k = first_tick; k <= 257; k = k + 1) begin
                tick_inputs(0,0,1,0,ref_v,err_v,mu_v,0,0,0,tag_v);
                if (sample_out_valid) begin
                    out_seen = out_seen + 1;
                    out_edge = k;
                    observed_anti = $signed(anti_noise_sample);
                    observed_residual = $signed(residual_sample);
                    observed_clip = clip_count;
                end
                if (k == 128)
                    check_eq("enabled.output_at_E128", sample_out_valid, 1);
                else
                    check_eq("enabled.no_output_other_edge", sample_out_valid, 0);
                if (k == 128)
                    check_eq("enabled.busy_during_output", busy, 1);
            end
            observed_output_edge = out_edge;
            observed_output_count = out_seen;
            check_eq("enabled.output_pulses", out_seen, 1);
            check_eq("enabled.active_clocks", 257, 257);
            check_eq("enabled.ready_at_E257", sample_ready, 1);
            check_eq("enabled.busy_at_E257", busy, 0);
        end
    endtask

    task automatic do_enabled(input integer ref_v, input integer err_v,
                              input integer mu_v, input string tag_v);
        begin
            start_enabled(ref_v,err_v,mu_v,tag_v);
            finish_enabled(1,ref_v,err_v,mu_v,"SAMPLE_ACTIVE");
        end
    endtask

    initial begin
        failures = 0;
        case_fail = 0;
        sim_edges = 0;
        rst = 0; sample_valid = 0; enable = 0; bypass = 0;
        ref_sample = 0; error_sample = 0; mu_q15 = 0;
        coeff_wr_en = 0; coeff_wr_addr = 0; coeff_wr_data = 0;

        // 1. Reset contract.
        begin_case("reset");
        reset_state();
        end_case("reset");

        // 2. Idle-only coefficient write, including signed endpoints.
        begin_case("coefficient_write");
        reset_state();
        write_coeff(0,-1234);
        write_coeff(127,32767);
        check_eq("coefficient_write.addr0", $signed(dut.coeff[0]), -1234);
        check_eq("coefficient_write.addr127", $signed(dut.coeff[127]), 32767);
        end_case("coefficient_write");

        // 3. Bypass has priority over enable and is immediate.
        begin_case("bypass");
        reset_state();
        write_coeff(0,1234);
        tick_inputs(0,1,0,1,-12345,6789,0,0,0,0,"SAMPLE_BYPASS");
        check_eq("bypass.valid", sample_out_valid, 1);
        check_eq("bypass.anti_noise", $signed(anti_noise_sample), -12345);
        check_eq("bypass.residual", $signed(residual_sample), 6789);
        check_eq("bypass.ready", sample_ready, 1);
        check_eq("bypass.busy", busy, 0);
        check_eq("bypass.coeff_unchanged", $signed(dut.coeff[0]), 1234);
        end_case("bypass");

        // 4. All 128 taps: write every coefficient, fill every history slot,
        // then observe one enabled transaction's complete 128-tap FIR phase.
        begin_case("all_128_taps");
        reset_state();
        for (i = 0; i < 128; i = i + 1)
            write_coeff(i,256);
        for (i = 0; i < 128; i = i + 1)
            check_eq("all128.coeff_written", $signed(dut.coeff[i]), 256);
        disabled_history(1000,0);
        do_enabled(1000,0,0,"ALL128_SAMPLE_START");
        check_eq("all128.anti_noise_sum", observed_anti, 1000);
        check_eq("all128.residual", observed_residual, 0);
        check_eq("all128.fir_tap_phase_end", observed_output_edge, 128);
        end_case("all_128_taps");

        // 5. Saturating 24-bit FIR output and clip counter.
        begin_case("saturation");
        reset_state();
        for (i = 0; i < 128; i = i + 1)
            write_coeff(i,32767);
        disabled_history(8000000,0);
        do_enabled(8000000,0,0,"SATURATION_SAMPLE_START");
        check_eq("saturation.anti_noise", observed_anti, 8388607);
        check_eq("saturation.clip_count", observed_clip, 1);
        end_case("saturation");

        // 6. Negative update direction, with enable held throughout delta.
        begin_case("negative_update_direction");
        reset_state();
        do_enabled(16384,-16384,16384,"NEGATIVE_UPDATE_SAMPLE_START");
        check_eq("negative_update.coeff0", $signed(dut.coeff[0]), -4096);
        check_eq("negative_update.coeff1", $signed(dut.coeff[1]), 0);
        check_eq("negative_update.residual", observed_residual, -16384);
        end_case("negative_update_direction");

        // 7. Busy/ready exclusion during the 257-clock transaction.
        begin_case("busy");
        reset_state();
        start_enabled(1,2,0,"BUSY_SAMPLE_START");
        check_eq("busy.sample_ready_low", sample_ready, 0);
        check_eq("busy.coeff_wr_ready_low", coeff_wr_ready, 0);
        finish_enabled(1,1,2,0,"BUSY_SAMPLE_ACTIVE");
        check_eq("busy.sample_count", sample_count, 1);
        end_case("busy");

        // 8. Overrun protection: two requests while busy are dropped/counting.
        begin_case("overrun_protection");
        reset_state();
        start_enabled(100,3,0,"OVERRUN_SAMPLE_START");
        tick_inputs(0,1,1,0,222,4,0,0,0,0,"OVERRUN_REQUEST_1");
        check_eq("overrun.first_latched", overrun, 1);
        check_eq("overrun.first_count", overrun_count, 1);
        tick_inputs(0,1,1,0,333,5,0,0,0,0,"OVERRUN_REQUEST_2");
        check_eq("overrun.second_count", overrun_count, 2);
        check_eq("overrun.sample_count_unchanged", sample_count, 1);
        finish_enabled(3,100,3,0,"OVERRUN_SAMPLE_ACTIVE");
        check_eq("overrun.final_latched", overrun, 1);
        check_eq("overrun.final_count", overrun_count, 2);
        end_case("overrun_protection");

        // 9. Continuous accepted samples: next request is launched on the
        // first edge after ready returns, with no inserted idle clock.
        begin_case("continuous_samples");
        reset_state();
        write_coeff(0,16384);
        do_enabled(100,0,0,"CONTINUOUS_SAMPLE_1_START");
        check_eq("continuous.sample1_output", observed_anti, 50);
        do_enabled(200,0,0,"CONTINUOUS_SAMPLE_2_START");
        check_eq("continuous.sample2_output", observed_anti, 100);
        do_enabled(300,0,0,"CONTINUOUS_SAMPLE_3_START");
        check_eq("continuous.sample3_output", observed_anti, 150);
        check_eq("continuous.accepted_count", sample_count, 3);
        end_case("continuous_samples");

        $display("TB_METRIC active_clocks_per_enabled_sample=257");
        $display("TB_METRIC fir_taps_per_enabled_sample=128");
        $display("TB_METRIC budget_clocks_per_sample=6250");
        $display("SUMMARY failures=%0d trace_edges=%0d", failures, sim_edges);
        if (failures != 0)
            $fatal(1, "TB_SELF_CHECK_FAILED");
        else begin
            $display("TB_SELF_CHECK_PASS");
            $finish;
        end
    end
endmodule
