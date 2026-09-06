`timescale 1ns/1ps
// Generic open-drain I2C byte-write sequencer.
//
// Transaction format is START, {7-bit device address, write bit}, register
// byte, data byte, STOP.  The device/register/data values are supplied by the
// caller; no codec address or register map is embedded here.  scl_oe_low and
// sda_oe_low are open-drain enables (1 drives low, 0 releases the line).
// Clock stretching and arbitration are intentionally outside this MVP.
module anc_i2c_byte_writer #(
    parameter integer CLK_DIV = 4
) (
    input  logic       clk,
    input  logic       rst,
    input  logic       start,
    input  logic [6:0] device_addr,
    input  logic [7:0] register_addr,
    input  logic [7:0] register_data,
    input  logic       sda_in,
    output logic       scl_oe_low,
    output logic       sda_oe_low,
    output logic       busy,
    output logic       done,
    output logic       nack
);
    localparam integer DIV_WIDTH = (CLK_DIV < 2) ? 1 : $clog2(CLK_DIV);
    localparam logic [3:0] ST_IDLE     = 4'd0;
    localparam logic [3:0] ST_START_A  = 4'd1;
    localparam logic [3:0] ST_START_B  = 4'd2;
    localparam logic [3:0] ST_SEND_LOW = 4'd3;
    localparam logic [3:0] ST_SEND_HIGH= 4'd4;
    localparam logic [3:0] ST_ACK_LOW  = 4'd5;
    localparam logic [3:0] ST_ACK_HIGH = 4'd6;
    localparam logic [3:0] ST_STOP_A   = 4'd7;
    localparam logic [3:0] ST_STOP_B   = 4'd8;
    localparam logic [3:0] ST_STOP_C   = 4'd9;

    logic [3:0] state;
    logic [DIV_WIDTH-1:0] div_count;
    logic [7:0] tx_byte;
    logic [2:0] bit_index;
    logic [1:0] byte_index;

    always_comb begin
        scl_oe_low = 1'b0;
        sda_oe_low = 1'b0;
        case (state)
            ST_START_A: begin sda_oe_low = 1'b1; end
            ST_START_B: begin scl_oe_low = 1'b1; sda_oe_low = 1'b1; end
            ST_SEND_LOW: begin
                scl_oe_low = 1'b1;
                sda_oe_low = (tx_byte[bit_index] == 1'b0);
            end
            ST_SEND_HIGH: begin
                sda_oe_low = (tx_byte[bit_index] == 1'b0);
            end
            ST_ACK_LOW: begin
                scl_oe_low = 1'b1;
            end
            ST_ACK_HIGH: begin
                // Release SDA so the target can drive ACK/NACK.
            end
            ST_STOP_A: begin
                scl_oe_low = 1'b1;
                sda_oe_low = 1'b1;
            end
            ST_STOP_B: begin sda_oe_low = 1'b1; end
            ST_STOP_C: begin end
            default: begin end
        endcase
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            state     <= ST_IDLE;
            div_count <= '0;
            tx_byte   <= 8'b0;
            bit_index <= 3'd7;
            byte_index<= 2'd0;
            busy      <= 1'b0;
            done      <= 1'b0;
            nack      <= 1'b0;
        end else begin
            done <= 1'b0;
            if (state == ST_IDLE) begin
                div_count <= '0;
                if (start) begin
                    state      <= ST_START_A;
                    tx_byte    <= {device_addr, 1'b0};
                    bit_index  <= 3'd7;
                    byte_index <= 2'd0;
                    busy       <= 1'b1;
                    nack       <= 1'b0;
                end
            end else if (div_count == CLK_DIV-1) begin
                div_count <= '0;
                case (state)
                    ST_START_A: begin
                        state <= ST_START_B;
                    end
                    ST_START_B: begin
                        state <= ST_SEND_LOW;
                    end
                    ST_SEND_LOW: begin
                        state <= ST_SEND_HIGH;
                    end
                    ST_SEND_HIGH: begin
                        if (bit_index == 3'd0) begin
                            state <= ST_ACK_LOW;
                        end else begin
                            bit_index <= bit_index - 3'd1;
                            state     <= ST_SEND_LOW;
                        end
                    end
                    ST_ACK_LOW: begin
                        state <= ST_ACK_HIGH;
                    end
                    ST_ACK_HIGH: begin
                        if (sda_in) begin
                            nack  <= 1'b1;
                            state <= ST_STOP_A;
                        end else if (byte_index == 2'd2) begin
                            state <= ST_STOP_A;
                        end else begin
                            byte_index <= byte_index + 2'd1;
                            bit_index  <= 3'd7;
                            if (byte_index == 2'd0)
                                tx_byte <= register_addr;
                            else
                                tx_byte <= register_data;
                            state <= ST_SEND_LOW;
                        end
                    end
                    ST_STOP_A: begin
                        state <= ST_STOP_B;
                    end
                    ST_STOP_B: begin
                        state <= ST_STOP_C;
                    end
                    ST_STOP_C: begin
                        state <= ST_IDLE;
                        busy  <= 1'b0;
                        done  <= 1'b1;
                    end
                    default: state <= ST_IDLE;
                endcase
            end else begin
                div_count <= div_count + 1'b1;
            end
        end
    end
endmodule
