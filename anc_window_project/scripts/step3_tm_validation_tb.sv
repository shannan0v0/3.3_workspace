`timescale 1ns/1ps
module step3_tm_validation_tb;
    logic clk;
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

    string trace_path;
    string coeff_path;
    integer trace_fd;
    integer coeff_fd;
    integer cycle;
    integer case_id;
    integer i;
    integer v;

    anc_fx_lms_tm_core dut (
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

    task automatic tick;
        input integer v_rst;
        input integer v_valid;
        input integer v_enable;
        input integer v_bypass;
        input integer v_ref;
        input integer v_error;
        input integer v_mu;
        input integer v_wr_en;
        input integer v_wr_addr;
        input integer v_wr_data;
        begin
            rst = v_rst;
            sample_valid = v_valid;
            enable = v_enable;
            bypass = v_bypass;
            ref_sample = v_ref;
            error_sample = v_error;
            mu_q15 = v_mu;
            coeff_wr_en = v_wr_en;
            coeff_wr_addr = v_wr_addr;
            coeff_wr_data = v_wr_data;
            @(posedge clk);
            #1;
            cycle = cycle + 1;
            $fwrite(trace_fd,
                "%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d\n",
                cycle, case_id, v_rst, v_valid, v_enable, v_bypass,
                v_ref, v_error, v_mu, v_wr_en, v_wr_addr, v_wr_data,
                sample_ready, coeff_wr_ready, busy, overrun, overrun_count,
                sample_out_valid, $signed(anti_noise_sample),
                $signed(residual_sample), sample_count, clip_count);
        end
    endtask

    task automatic reset_sequence;
        begin
            tick(1,0,0,0,0,0,0,0,0,0);
            tick(1,0,0,0,0,0,0,0,0,0);
            tick(0,0,0,0,0,0,0,0,0,0);
        end
    endtask

    task automatic wait_enabled;
        begin
            // E0 is the acceptance edge; E1..E257 complete the 257-clock schedule.
            repeat (257) tick(0,0,1,0,0,0,0,0,0,0);
        end
    endtask

    task automatic dump_coeff;
        input integer dump_case;
        begin
            for (i = 0; i < 128; i = i + 1)
                $fwrite(coeff_fd, "%0d,%0d,%0d\n", dump_case, i, $signed(dut.coeff[i]));
        end
    endtask

    initial begin
        clk = 1'b0;
        rst = 1'b0;
        sample_valid = 1'b0;
        enable = 1'b0;
        bypass = 1'b0;
        ref_sample = 24'sd0;
        error_sample = 24'sd0;
        mu_q15 = 16'sd0;
        coeff_wr_en = 1'b0;
        coeff_wr_addr = 7'd0;
        coeff_wr_data = 16'sd0;
        cycle = 0;
        case_id = 0;

        if (!$value$plusargs("TRACE=%s", trace_path)) trace_path = "step3_tm_trace.csv";
        if (!$value$plusargs("COEFF=%s", coeff_path)) coeff_path = "step3_tm_coeff.csv";
        trace_fd = $fopen(trace_path, "w");
        coeff_fd = $fopen(coeff_path, "w");
        if (trace_fd == 0 || coeff_fd == 0) begin
            $display("TB_FATAL cannot open TRACE=%s COEFF=%s", trace_path, coeff_path);
            $finish(2);
        end
        $fwrite(trace_fd, "cycle,case_id,rst,sample_valid,enable,bypass,ref_sample,error_sample,mu_q15,coeff_wr_en,coeff_wr_addr,coeff_wr_data,sample_ready,coeff_wr_ready,busy,overrun,overrun_count,sample_out_valid,anti_noise_sample,residual_sample,sample_count,clip_count\n");
        $fwrite(coeff_fd, "case_id,addr,coeff\n");

        // CASE 1: reset must clear state, counters, flags, history-visible coeffs.
        case_id = 1; $display("[CASE 1 RESET] START");
        reset_sequence();
        tick(0,0,0,0,0,0,0,1,5,1234);
        tick(0,1,1,0,100,1,0,0,0,0);
        tick(0,1,1,0,101,1,0,0,0,0); // busy request -> overrun
        wait_enabled();
        tick(1,0,0,0,0,0,0,0,0,0);
        tick(1,0,0,0,0,0,0,0,0,0);
        tick(0,0,0,0,0,0,0,0,0,0);
        dump_coeff(case_id);
        $display("[CASE 1 RESET] END");

        // CASE 2: bypass is immediate, has priority over enable, and is not busy.
        case_id = 2; $display("[CASE 2 BYPASS] START");
        reset_sequence();
        tick(0,1,0,1,-123456,654321,-7,0,0,0);
        tick(0,0,0,0,0,0,0,0,0,0);
        dump_coeff(case_id);
        $display("[CASE 2 BYPASS] END");

        // CASE 3: write every address and test a write concurrent with acceptance.
        case_id = 3; $display("[CASE 3 COEFF_WRITES] START");
        reset_sequence();
        for (i = 0; i < 128; i = i + 1)
            tick(0,0,0,0,0,0,0,1,i,(-16000 + 250*i));
        tick(0,1,1,0,1000,0,0,1,0,16384);
        wait_enabled();
        dump_coeff(case_id);
        $display("[CASE 3 COEFF_WRITES] END");

        // CASE 4: all coefficients/history at positive full scale must clip 24-bit output.
        case_id = 4; $display("[CASE 4 OUTPUT_SATURATION] START");
        reset_sequence();
        for (i = 0; i < 128; i = i + 1)
            tick(0,0,0,0,0,0,0,1,i,32767);
        for (i = 0; i < 127; i = i + 1)
            tick(0,1,0,1,8388607,0,0,0,0,0);
        tick(0,1,1,0,8388607,0,0,0,0,0);
        wait_enabled();
        dump_coeff(case_id);
        $display("[CASE 4 OUTPUT_SATURATION] END");

        // CASE 5: positive update at coeff max must saturate at +32767.
        case_id = 5; $display("[CASE 5 COEFF_SATURATION] START");
        reset_sequence();
        tick(0,0,0,0,0,0,0,1,0,32767);
        tick(0,1,1,0,32767,32767,32767,0,0,0);
        wait_enabled();
        dump_coeff(case_id);
        $display("[CASE 5 COEFF_SATURATION] END");

        // CASE 6: negative gradient/update direction must remain negative.
        case_id = 6; $display("[CASE 6 NEGATIVE_UPDATE] START");
        reset_sequence();
        tick(0,1,1,0,16384,-16384,16384,0,0,0);
        wait_enabled();
        dump_coeff(case_id);
        $display("[CASE 6 NEGATIVE_UPDATE] END");

        // CASE 7: nonzero circular history proves all 128 taps update.
        case_id = 7; $display("[CASE 7 ALL_128_TAPS] START");
        reset_sequence();
        for (i = 0; i < 127; i = i + 1)
            tick(0,1,0,1,(20000 + 50*i),0,0,0,0,0);
        tick(0,1,1,0,26500,32767,16384,0,0,0);
        wait_enabled();
        dump_coeff(case_id);
        $display("[CASE 7 ALL_128_TAPS] END");

        // CASE 8: samples are offered at the 6250-clock/sample budget boundary.
        case_id = 8; $display("[CASE 8 CONTINUOUS_16KHZ] START");
        reset_sequence();
        tick(0,1,1,0,1000,0,0,0,0,0);
        repeat (6249) tick(0,0,1,0,0,0,0,0,0,0);
        tick(0,1,1,0,2000,0,0,0,0,0);
        repeat (6249) tick(0,0,1,0,0,0,0,0,0,0);
        tick(0,1,1,0,3000,0,0,0,0,0);
        wait_enabled();
        dump_coeff(case_id);
        $display("[CASE 8 CONTINUOUS_16KHZ] END");

        // CASE 9: busy requests are rejected/counting; writes while busy are rejected.
        case_id = 9; $display("[CASE 9 BUSY_OVERRUN] START");
        reset_sequence();
        tick(0,1,1,0,4000,100,0,0,0,0);
        tick(0,1,1,0,4001,100,0,1,1,12345);
        repeat (9) tick(0,1,1,0,4002,100,0,0,0,0);
        repeat (247) tick(0,0,1,0,0,0,0,0,0,0);
        dump_coeff(case_id);
        $display("[CASE 9 BUSY_OVERRUN] END");

        $fclose(trace_fd);
        $fclose(coeff_fd);
        $display("TB_TRACE_COMPLETE cycles=%0d trace=%s coeff=%s", cycle, trace_path, coeff_path);
        $finish(0);
    end
endmodule
