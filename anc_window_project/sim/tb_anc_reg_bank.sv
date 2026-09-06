`timescale 1ns/1ps
module tb_anc_reg_bank;
  logic clk=0, rst, bus_valid, bus_write;
  always #5 clk=~clk;
  logic [11:0] bus_addr; logic [31:0] bus_wdata, bus_rdata;
  logic bus_rvalid, bus_ready, enable, bypass; logic [15:0] mu_q15;
  logic coeff_wr_en; logic [6:0] coeff_wr_addr; logic signed [15:0] coeff_wr_data;
  logic [31:0] sample_count, clip_count; logic signed [23:0] anti_noise_sample, residual_sample;
  integer fails=0;
  anc_reg_bank dut(.*);
  task automatic wr(input [11:0] a,input [31:0] d);
    begin @(negedge clk); bus_addr=a; bus_wdata=d; bus_valid=1; bus_write=1;
      @(posedge clk); #1; bus_valid=0; bus_write=0; end
  endtask
  task automatic rd(input [11:0] a,input [31:0] exp);
    begin @(negedge clk); bus_addr=a; bus_valid=1; bus_write=0;
      @(posedge clk); #1; if(!bus_rvalid || bus_rdata!==exp) begin
        $display("FAIL read %h got %h/%b exp %h",a,bus_rdata,bus_rvalid,exp); fails=fails+1; end
      bus_valid=0; end
  endtask
  initial begin
    bus_valid=0; bus_write=0; bus_addr=0; bus_wdata=0; sample_count=0; clip_count=0;
    anti_noise_sample=0; residual_sample=0; rst=1; repeat(2) @(posedge clk); @(negedge clk); rst=0;
    if(!bus_ready) begin $display("FAIL bus_ready"); fails=fails+1; end
    rd(12'h000,32'h2); rd(12'h004,32'd64);
    wr(12'h000,32'h3); if(!enable || !bypass) begin $display("FAIL control"); fails=fails+1; end
    wr(12'h004,32'h1234); if(mu_q15!==16'h1234) begin $display("FAIL mu"); fails=fails+1; end
    wr(12'h17c,32'hffff8001); if(!coeff_wr_en || coeff_wr_addr!==7'd31 || coeff_wr_data!==-16'sd32767) begin
      $display("FAIL coeff pulse %b %0d %0d",coeff_wr_en,coeff_wr_addr,coeff_wr_data); fails=fails+1; end
    sample_count=32'd9; clip_count=32'd2; anti_noise_sample=-24'sd5; residual_sample=24'sd7;
    rd(12'h008,32'h3); rd(12'h00c,32'd9); rd(12'h010,32'd2); rd(12'h014,32'hffff_fffb); rd(12'h018,32'd7);
    if(fails==0) $display("TB_REG_PASS"); else $fatal(1,"TB_REG_FAIL %0d",fails);
    $finish;
  end
endmodule
