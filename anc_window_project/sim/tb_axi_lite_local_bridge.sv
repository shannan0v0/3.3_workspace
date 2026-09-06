`timescale 1ns/1ps
module tb_axi_lite_local_bridge;
    logic clk = 1'b0;
    always #5 clk = ~clk;

    logic aresetn = 1'b0;
    logic [11:0] awaddr, araddr;
    logic awvalid, awready, wvalid, wready, arvalid, arready;
    logic [31:0] wdata, rdata, bus_rdata;
    logic [3:0] wstrb;
    logic [1:0] bresp, rresp;
    logic bvalid, bready, rvalid, rready;
    logic bus_valid, bus_write, bus_ready, bus_rvalid;
    logic [11:0] bus_addr;
    logic [31:0] bus_wdata;
    logic rst;
    logic enable, bypass;
    logic [15:0] mu_q15;
    logic coeff_wr_en;
    logic [6:0] coeff_wr_addr;
    logic signed [15:0] coeff_wr_data;
    logic [31:0] sample_count, clip_count;
    logic signed [23:0] anti_noise_sample, residual_sample;
    integer fails = 0;

    assign rst = !aresetn;

    anc_axi_lite_local_bridge dut_bridge (
        .s_axi_aclk(clk), .s_axi_aresetn(aresetn),
        .s_axi_awaddr(awaddr), .s_axi_awvalid(awvalid), .s_axi_awready(awready),
        .s_axi_wdata(wdata), .s_axi_wstrb(wstrb), .s_axi_wvalid(wvalid), .s_axi_wready(wready),
        .s_axi_bresp(bresp), .s_axi_bvalid(bvalid), .s_axi_bready(bready),
        .s_axi_araddr(araddr), .s_axi_arvalid(arvalid), .s_axi_arready(arready),
        .s_axi_rdata(rdata), .s_axi_rresp(rresp), .s_axi_rvalid(rvalid), .s_axi_rready(rready),
        .bus_valid(bus_valid), .bus_write(bus_write), .bus_addr(bus_addr), .bus_wdata(bus_wdata),
        .bus_ready(bus_ready), .bus_rdata(bus_rdata), .bus_rvalid(bus_rvalid)
    );

    anc_reg_bank dut_regs (
        .clk(clk), .rst(rst), .bus_valid(bus_valid), .bus_write(bus_write),
        .bus_addr(bus_addr), .bus_wdata(bus_wdata), .bus_rdata(bus_rdata),
        .bus_rvalid(bus_rvalid), .bus_ready(bus_ready), .enable(enable), .bypass(bypass),
        .mu_q15(mu_q15), .coeff_wr_en(coeff_wr_en), .coeff_wr_addr(coeff_wr_addr),
        .coeff_wr_data(coeff_wr_data), .sample_count(sample_count), .clip_count(clip_count),
        .anti_noise_sample(anti_noise_sample), .residual_sample(residual_sample)
    );

    task automatic send_aw(input [11:0] a);
        begin
            @(negedge clk); awaddr = a; awvalid = 1'b1;
            while (!awready) @(posedge clk);
            @(negedge clk); awvalid = 1'b0;
        end
    endtask

    task automatic send_w(input [31:0] d, input [3:0] s);
        begin
            @(negedge clk); wdata = d; wstrb = s; wvalid = 1'b1;
            while (!wready) @(posedge clk);
            @(negedge clk); wvalid = 1'b0;
        end
    endtask

    task automatic axi_write(input [11:0] a, input [31:0] d, input [3:0] s,
                             input bit w_first, input [1:0] expected_resp);
        begin
            if (w_first) begin
                send_w(d, s);
                send_aw(a);
            end else begin
                send_aw(a);
                send_w(d, s);
            end
            while (!bvalid) @(posedge clk);
            if (bresp !== expected_resp) begin
                $display("FAIL AXI write response %b expected %b", bresp, expected_resp);
                fails = fails + 1;
            end
            @(negedge clk); bready = 1'b1;
            @(posedge clk); #1 bready = 1'b0;
        end
    endtask

    task automatic axi_read(input [11:0] a, input [31:0] expected);
        begin
            @(negedge clk); araddr = a; arvalid = 1'b1;
            while (!arready) @(posedge clk);
            @(negedge clk); arvalid = 1'b0;
            while (!rvalid) @(posedge clk);
            if (rresp !== 2'b00 || rdata !== expected) begin
                $display("FAIL AXI read addr %h data %h expected %h resp %b", a, rdata, expected, rresp);
                fails = fails + 1;
            end
            @(negedge clk); rready = 1'b1;
            @(posedge clk); #1 rready = 1'b0;
        end
    endtask

    initial begin
        awaddr=0; araddr=0; awvalid=0; wvalid=0; arvalid=0;
        wdata=0; wstrb=0; bready=0; rready=0;
        sample_count=32'd19; clip_count=32'd3;
        anti_noise_sample=-24'sd11; residual_sample=24'sd13;
        repeat (3) @(posedge clk);
        aresetn = 1'b1;
        repeat (2) @(posedge clk);

        // AW-before-W and W-before-AW cover the independent AXI channels.
        axi_write(12'h000, 32'h0000_0001, 4'hf, 1'b0, 2'b00);
        if (!enable || bypass) begin
            $display("FAIL control via AXI enable=%b bypass=%b", enable, bypass);
            fails = fails + 1;
        end
        axi_write(12'h004, 32'h0000_2468, 4'hf, 1'b1, 2'b00);
        axi_read(12'h004, 32'h0000_2468);

        // Adversarial partial write: it must not silently alter a 32-bit register.
        axi_write(12'h004, 32'h0000_ffff, 4'b0001, 1'b0, 2'b10);
        axi_read(12'h004, 32'h0000_2468);
        axi_read(12'h00c, 32'd19);
        axi_read(12'h014, 32'hffff_fff5);

        if (fails == 0) $display("TB_AXI_PASS");
        else $fatal(1, "TB_AXI_FAIL count=%0d", fails);
        $finish;
    end
endmodule
