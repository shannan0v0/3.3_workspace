`timescale 1ns/1ps
module tb_anc_cdc_pulse_bridge;
    logic src_clk = 1'b0;
    logic dst_clk = 1'b0;
    always #5 src_clk = ~src_clk;
    always #7 dst_clk = ~dst_clk;
    logic src_rst = 1'b1;
    logic dst_rst = 1'b1;
    logic pulse_src = 1'b0;
    logic pulse_dst;
    integer dst_count = 0;
    integer fails = 0;
    logic previous_dst_pulse = 1'b0;

    anc_cdc_pulse_bridge dut (
        .src_clk(src_clk), .src_rst(src_rst), .pulse_src(pulse_src),
        .dst_clk(dst_clk), .dst_rst(dst_rst), .pulse_dst(pulse_dst)
    );

    always @(posedge dst_clk) begin
        if (pulse_dst && previous_dst_pulse) begin
            $display("FAIL CDC destination pulse wider than one cycle");
            fails = fails + 1;
        end
        if (pulse_dst)
            dst_count = dst_count + 1;
        previous_dst_pulse = pulse_dst;
    end

    task automatic source_pulse;
        begin
            @(negedge src_clk); pulse_src = 1'b1;
            @(negedge src_clk); pulse_src = 1'b0;
            repeat (8) @(posedge src_clk);
        end
    endtask

    initial begin
        repeat (3) @(posedge src_clk);
        src_rst = 1'b0;
        dst_rst = 1'b0;

        source_pulse();
        source_pulse();
        source_pulse();
        repeat (10) @(posedge dst_clk);
        if (dst_count !== 3) begin
            $display("FAIL CDC count after asynchronous pulses got %0d", dst_count);
            fails = fails + 1;
        end

        // Reset is an adversarial boundary: no event may be invented by reset.
        src_rst = 1'b1; dst_rst = 1'b1;
        repeat (3) @(posedge dst_clk);
        src_rst = 1'b0; dst_rst = 1'b0;
        source_pulse();
        repeat (8) @(posedge dst_clk);
        if (dst_count !== 4) begin
            $display("FAIL CDC count after reset got %0d", dst_count);
            fails = fails + 1;
        end

        if (fails == 0) $display("TB_CDC_PASS");
        else $fatal(1, "TB_CDC_FAIL count=%0d", fails);
        $finish;
    end
endmodule
