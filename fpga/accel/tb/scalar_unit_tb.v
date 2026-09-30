`timescale 1ns/1ps

module scalar_unit_tb;

    // inputs
    reg         clk;
    reg         reset;
    reg [2:0]   address;
    reg         read;
    reg         write;
    reg [31:0]   writedata;

    // output
    wire [31:0] readdata;

    // instatiate dut
    scalar_unit dut (
        .clk        (clk),
        .reset      (reset),
        .address    (address),
        .read       (read),
        .write      (write),
        .writedata  (writedata),
        .readdata   (readdata)
    );

    // clock simulation 50 MHz
    initial begin
        clk = 1'b0;
    end

    always #10 clk = ~clk;

    // test
    initial begin
        reset       = 1'b1;
        address     = 3'b000;
        read        = 1'b0;
        write       = 1'b0;
        writedata   = 32'b0;

        // reset two clock cycles
        #40;
        reset = 1'b0;

        #20;

        // write A=7
        address     = 3'b000;
        writedata   = 32'd7;
        write       = 1'b1;

        #20;

        write = 1'b0;

        // delay
        #100;

        // write B=3
        address     = 3'b001;
        writedata   = 32'd3;
        write       = 1'b1;

        #20;

        write   = 1'b0;

        // delay
        #100;

        // write op = ADD
        address     = 3'b010;
        writedata   = 32'd0;
        write       = 1'b1;

        #20;

        write = 1'b0;

        #100;

        // send input_valid
        address     = 3'b011;
        writedata   = 32'd1;
        write       = 1'b1;

        #20;

        write = 1'b0;

        // result propagate/capture
        #40;

        // read result
        address = 3'b100;
        read    = 1'b1;

        #20;

        if (readdata == 32'd10)
            $display("PASS: 7 + 3 = 10");
        else
            $display("FAIL: received %d", readdata);

        read = 1'b0;

        #20;
        $stop;
    end
endmodule