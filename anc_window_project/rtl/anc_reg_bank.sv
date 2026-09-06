`timescale 1ns/1ps
// Small synchronous control/status register bank for the ANC PL core.
// bus_addr is a byte address; reads return valid for one clock after a request.
module anc_reg_bank (
    input  logic                   clk,
    input  logic                   rst,
    input  logic                   bus_valid,
    input  logic                   bus_write,
    input  logic        [11:0]     bus_addr,
    input  logic        [31:0]     bus_wdata,
    output logic        [31:0]     bus_rdata,
    output logic                   bus_rvalid,
    output logic                   bus_ready,
    output logic                   enable,
    output logic                   bypass,
    output logic        [15:0]     mu_q15,
    output logic                   coeff_wr_en,
    output logic        [6:0]      coeff_wr_addr,
    output logic signed [15:0]     coeff_wr_data,
    input  logic        [31:0]     sample_count,
    input  logic        [31:0]     clip_count,
    input  logic signed [23:0]     anti_noise_sample,
    input  logic signed [23:0]     residual_sample
);

    assign bus_ready = 1'b1;

    always_comb begin
        bus_rdata = 32'd0;
        case (bus_addr)
            12'h000: bus_rdata = {30'd0, bypass, enable};
            12'h004: bus_rdata = {16'd0, mu_q15};
            12'h008: bus_rdata = {30'd0, (clip_count != 0), (sample_count != 0)};
            12'h00c: bus_rdata = sample_count;
            12'h010: bus_rdata = clip_count;
            12'h014: bus_rdata = {{8{anti_noise_sample[23]}}, anti_noise_sample};
            12'h018: bus_rdata = {{8{residual_sample[23]}}, residual_sample};
            default: bus_rdata = 32'd0;
        endcase
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            enable        <= 1'b0;
            bypass        <= 1'b1;
            mu_q15        <= 16'd64;
            bus_rvalid    <= 1'b0;
            coeff_wr_en   <= 1'b0;
            coeff_wr_addr <= 7'd0;
            coeff_wr_data <= 16'sd0;
        end else begin
            bus_rvalid  <= 1'b0;
            coeff_wr_en <= 1'b0;
            if (bus_valid) begin
                if (bus_write) begin
                    case (bus_addr)
                        12'h000: begin
                            enable <= bus_wdata[0];
                            bypass <= bus_wdata[1];
                        end
                        12'h004: mu_q15 <= bus_wdata[15:0];
                        default: begin
                            if ((bus_addr >= 12'h100) &&
                                (bus_addr <= 12'h2fc) &&
                                (bus_addr[1:0] == 2'b00)) begin
                                coeff_wr_en   <= 1'b1;
                                coeff_wr_addr <= (bus_addr - 12'h100) >> 2;
                                coeff_wr_data <= bus_wdata[15:0];
                            end
                        end
                    endcase
                end else begin
                    bus_rvalid <= 1'b1;
                end
            end
        end
    end
endmodule
