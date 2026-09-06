`timescale 1ns/1ps
module tb_anc_i2c_byte_writer;
    logic clk = 1'b0;
    always #1 clk = ~clk;
    logic rst = 1'b1;
    logic start = 1'b0;
    logic [6:0] device_addr;
    logic [7:0] register_addr, register_data;
    logic sda_oe_low, scl_oe_low;
    logic busy, done, nack;
    tri1 scl_line;
    tri1 sda_line;
    logic slave_sda_low = 1'b0;
    integer bit_count = 0;
    integer byte_index = 0;
    integer nack_byte = -1;
    integer ack_active = 0;
    reg [7:0] rx_shift = 8'b0;
    reg [7:0] captured0 = 8'b0;
    reg [7:0] captured1 = 8'b0;
    reg [7:0] captured2 = 8'b0;
    integer stop_count = 0;
    integer fails = 0;

    assign scl_line = scl_oe_low ? 1'b0 : 1'bz;
    assign sda_line = sda_oe_low ? 1'b0 : 1'bz;
    assign sda_line = slave_sda_low ? 1'b0 : 1'bz;

    anc_i2c_byte_writer #(.CLK_DIV(2)) dut (
        .clk(clk), .rst(rst), .start(start), .device_addr(device_addr),
        .register_addr(register_addr), .register_data(register_data),
        .sda_in(sda_line), .scl_oe_low(scl_oe_low), .sda_oe_low(sda_oe_low),
        .busy(busy), .done(done), .nack(nack)
    );

    // Minimal open-drain target model: ACK every byte except nack_byte.
    always @(posedge scl_line) begin
        if (bit_count < 8) begin
            rx_shift = {rx_shift[6:0], sda_line};
            bit_count = bit_count + 1;
        end else begin
            if (byte_index == 0) captured0 = rx_shift;
            if (byte_index == 1) captured1 = rx_shift;
            if (byte_index == 2) captured2 = rx_shift;
            if (byte_index == nack_byte)
                slave_sda_low = 1'b0;
            else
                slave_sda_low = 1'b1;
            ack_active = 1;
            bit_count = 0;
            byte_index = byte_index + 1;
        end
    end

    always @(negedge scl_line) begin
        if (ack_active) begin
            slave_sda_low = 1'b0;
            ack_active = 0;
        end
    end

    // SDA rising while SCL is high is the STOP edge (the initial pull-up is not
    // a transition), so this also checks the open-drain release sequence.
    always @(posedge sda_line) begin
        if (scl_line === 1'b1)
            stop_count = stop_count + 1;
    end

    task automatic run_tx(input integer selected_nack);
        begin
            nack_byte = selected_nack;
            bit_count = 0; byte_index = 0; rx_shift = 0;
            captured0 = 0; captured1 = 0; captured2 = 0;
            @(negedge clk); start = 1'b1;
            @(posedge clk); #1 start = 1'b0;
            while (!done) @(posedge clk);
            #1;
        end
    endtask

    initial begin
        device_addr = 7'h2a; register_addr = 8'h12; register_data = 8'h34;
        repeat (3) @(posedge clk);
        rst = 1'b0;
        repeat (2) @(posedge clk);

        run_tx(-1);
        if (nack || captured0 !== 8'h54 || captured1 !== 8'h12 || captured2 !== 8'h34) begin
            $display("FAIL I2C ACK tx nack=%b bytes=%h %h %h", nack, captured0, captured1, captured2);
            fails = fails + 1;
        end
        if (busy || scl_line !== 1'b1 || sda_line !== 1'b1) begin
            $display("FAIL I2C idle after ACK busy=%b scl=%b sda=%b", busy, scl_line, sda_line);
            fails = fails + 1;
        end

        // NACK the register byte: the master must stop and report it.
        run_tx(1);
        if (!nack || captured0 !== 8'h54) begin
            $display("FAIL I2C NACK handling nack=%b address=%h", nack, captured0);
            fails = fails + 1;
        end
        if (busy || scl_line !== 1'b1 || sda_line !== 1'b1 || stop_count < 2) begin
            $display("FAIL I2C STOP after NACK busy=%b scl=%b sda=%b stops=%0d", busy, scl_line, sda_line, stop_count);
            fails = fails + 1;
        end

        if (fails == 0) $display("TB_I2C_PASS");
        else $fatal(1, "TB_I2C_FAIL count=%0d", fails);
        $finish;
    end
endmodule
