`timescale 1ns/1ps
// AXI4-Lite slave bridge for the existing one-cycle local ANC bus.
//
// This adapter intentionally exposes no PS base address.  AW and W are
// buffered independently, full-word writes (WSTRB=4'b1111) are forwarded,
// and partial writes are rejected with SLVERR because the local bus has no
// byte-enable input.  The local read response is allowed to arrive later.
module anc_axi_lite_local_bridge #(
    parameter integer ADDR_WIDTH = 12
) (
    input  logic                   s_axi_aclk,
    input  logic                   s_axi_aresetn,
    input  logic [ADDR_WIDTH-1:0]  s_axi_awaddr,
    input  logic                   s_axi_awvalid,
    output logic                   s_axi_awready,
    input  logic [31:0]            s_axi_wdata,
    input  logic [3:0]             s_axi_wstrb,
    input  logic                   s_axi_wvalid,
    output logic                   s_axi_wready,
    output logic [1:0]             s_axi_bresp,
    output logic                   s_axi_bvalid,
    input  logic                   s_axi_bready,
    input  logic [ADDR_WIDTH-1:0]  s_axi_araddr,
    input  logic                   s_axi_arvalid,
    output logic                   s_axi_arready,
    output logic [31:0]            s_axi_rdata,
    output logic [1:0]             s_axi_rresp,
    output logic                   s_axi_rvalid,
    input  logic                   s_axi_rready,

    output logic                   bus_valid,
    output logic                   bus_write,
    output logic [ADDR_WIDTH-1:0]  bus_addr,
    output logic [31:0]            bus_wdata,
    input  logic                   bus_ready,
    input  logic [31:0]            bus_rdata,
    input  logic                   bus_rvalid
);
    localparam logic [2:0] S_IDLE        = 3'd0;
    localparam logic [2:0] S_WRITE_CHECK = 3'd1;
    localparam logic [2:0] S_WRITE_ISSUE = 3'd2;
    localparam logic [2:0] S_WRITE_RESP  = 3'd3;
    localparam logic [2:0] S_READ_ISSUE  = 3'd4;
    localparam logic [2:0] S_READ_WAIT   = 3'd5;
    localparam logic [2:0] S_READ_RESP  = 3'd6;

    logic [2:0] state;
    logic       aw_hold, w_hold;
    logic [ADDR_WIDTH-1:0] awaddr_hold;
    logic [31:0] wdata_hold;
    logic [3:0]  wstrb_hold;
    logic [ADDR_WIDTH-1:0] araddr_hold;
    logic [1:0] bresp_reg, rresp_reg;
    logic [31:0] rdata_reg;

    always_comb begin
        s_axi_awready = 1'b0;
        s_axi_wready  = 1'b0;
        s_axi_arready = 1'b0;
        s_axi_bvalid  = 1'b0;
        s_axi_bresp   = bresp_reg;
        s_axi_rvalid  = 1'b0;
        s_axi_rdata   = rdata_reg;
        s_axi_rresp   = rresp_reg;

        bus_valid = 1'b0;
        bus_write = 1'b0;
        bus_addr  = '0;
        bus_wdata = 32'b0;

        if (state == S_IDLE) begin
            s_axi_awready = !aw_hold;
            s_axi_wready  = !w_hold;
            // Give a write offered in the same cycle priority over a read.
            s_axi_arready = !aw_hold && !w_hold &&
                            !s_axi_awvalid && !s_axi_wvalid;
        end
        if (state == S_WRITE_ISSUE) begin
            bus_valid = 1'b1;
            bus_write = 1'b1;
            bus_addr  = awaddr_hold;
            bus_wdata = wdata_hold;
        end
        if ((state == S_READ_ISSUE) || (state == S_READ_WAIT)) begin
            bus_addr = araddr_hold;
        end
        if (state == S_READ_ISSUE)
            bus_valid = 1'b1;
        if (state == S_READ_RESP)
            s_axi_rvalid = 1'b1;
        if (state == S_WRITE_RESP)
            s_axi_bvalid = 1'b1;
    end

    always_ff @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            state       <= S_IDLE;
            aw_hold     <= 1'b0;
            w_hold      <= 1'b0;
            awaddr_hold <= '0;
            wdata_hold  <= 32'b0;
            wstrb_hold  <= 4'b0;
            araddr_hold <= '0;
            bresp_reg   <= 2'b00;
            rresp_reg   <= 2'b00;
            rdata_reg   <= 32'b0;
        end else begin
            case (state)
                S_IDLE: begin
                    if (s_axi_awvalid && s_axi_awready) begin
                        aw_hold     <= 1'b1;
                        awaddr_hold <= s_axi_awaddr;
                    end
                    if (s_axi_wvalid && s_axi_wready) begin
                        w_hold     <= 1'b1;
                        wdata_hold <= s_axi_wdata;
                        wstrb_hold <= s_axi_wstrb;
                    end

                    if (aw_hold && w_hold) begin
                        aw_hold <= 1'b0;
                        w_hold  <= 1'b0;
                        state   <= S_WRITE_CHECK;
                    end else if (s_axi_arvalid && s_axi_arready) begin
                        araddr_hold <= s_axi_araddr;
                        state       <= S_READ_ISSUE;
                    end
                end

                S_WRITE_CHECK: begin
                    if (wstrb_hold == 4'b1111) begin
                        state <= S_WRITE_ISSUE;
                    end else begin
                        bresp_reg <= 2'b10; // SLVERR: local bus has no byte strobes.
                        state     <= S_WRITE_RESP;
                    end
                end

                S_WRITE_ISSUE: begin
                    if (bus_ready) begin
                        bresp_reg <= 2'b00; // OKAY
                        state     <= S_WRITE_RESP;
                    end
                end

                S_WRITE_RESP: begin
                    if (s_axi_bready)
                        state <= S_IDLE;
                end

                S_READ_ISSUE: begin
                    if (bus_ready)
                        state <= S_READ_WAIT;
                end

                S_READ_WAIT: begin
                    if (bus_rvalid) begin
                        rdata_reg <= bus_rdata;
                        rresp_reg <= 2'b00; // OKAY
                        state     <= S_READ_RESP;
                    end
                end

                S_READ_RESP: begin
                    if (s_axi_rready)
                        state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end
endmodule
