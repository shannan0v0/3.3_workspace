`timescale 1ns/1ps
// Toggle-based pulse transfer between unrelated clock domains.
//
// A source pulse toggles an event bit; the destination synchronizes that bit
// through two flip-flops and emits one destination-clock pulse.  The source
// and destination resets must be asserted together during initialization.
// Pulses must be spaced far enough apart for the destination to observe each
// toggle; this module does not provide buffering or back-pressure.
module anc_cdc_pulse_bridge (
    input  logic src_clk,
    input  logic src_rst,
    input  logic pulse_src,
    input  logic dst_clk,
    input  logic dst_rst,
    output logic pulse_dst
);
    logic src_toggle;
    logic sync_ff1;
    logic sync_ff2;
    logic sync_ff2_d;

    always_ff @(posedge src_clk) begin
        if (src_rst)
            src_toggle <= 1'b0;
        else if (pulse_src)
            src_toggle <= ~src_toggle;
    end

    always_ff @(posedge dst_clk) begin
        if (dst_rst) begin
            sync_ff1  <= 1'b0;
            sync_ff2  <= 1'b0;
            sync_ff2_d<= 1'b0;
            pulse_dst <= 1'b0;
        end else begin
            sync_ff1   <= src_toggle;
            sync_ff2   <= sync_ff1;
            sync_ff2_d <= sync_ff2;
            pulse_dst  <= sync_ff2 ^ sync_ff2_d;
        end
    end
endmodule
