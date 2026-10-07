`timescale 1ns/1ps
module controller_unit_tb;
    reg clk = 0;
    always #10 clk = ~clk;
    reg reset = 1;
    reg [9:0] address = 0;
    reg read = 0, write = 0;
    reg [31:0] writedata = 0;
    wire [31:0] readdata;
    integer checks = 0, errors = 0;
    integer i;
    reg [31:0] status_value;

    controller_unit dut (.clk(clk), .reset(reset), .address(address),
        .read(read), .write(write), .writedata(writedata), .readdata(readdata));

    // Prevent a broken controller/handshake from hanging simulation forever.
    initial begin
        #2000000;
        $display("FAIL: global simulation timeout");
        $finish;
    end

    task check;
        input [31:0] actual, expected;
        begin
            checks = checks + 1;
            if (actual !== expected) begin
                errors = errors + 1;
                $display("FAIL check %0d at %0t: got %h expected %h",
                         checks, $time, actual, expected);
            end
        end
    endtask

    // Address arguments are WORD offsets on the Avalon slave interface.
    task bus_write;
        input [9:0] addr;
        input [31:0] value;
        begin
            @(negedge clk);
            address = addr; writedata = value; write = 1; read = 0;
            @(negedge clk); write = 0;
        end
    endtask
    task bus_read;
        input [9:0] addr;
        output [31:0] value;
        begin
            @(negedge clk); address = addr; read = 1; write = 0;
            #1; value = readdata;
            @(negedge clk); read = 0;
        end
    endtask
    task expect_read;
        input [9:0] addr;
        input [31:0] expected;
        reg [31:0] value;
        begin bus_read(addr, value); check(value, expected); end
    endtask
    task put_word;
        input [8:0] index;
        input [31:0] value;
        begin bus_write({1'b1, index}, value); end
    endtask
    task launch;
        input [31:0] words;
        begin bus_write(10'd2, words); bus_write(10'd0, 32'd1); end
    endtask
    task wait_stop;
        input [31:0] expected_status;
        integer polls;
        reg [31:0] value;
        begin
            polls = 0; value = 1;
            while ((value[0] === 1'b1) && (polls < 5000)) begin
                bus_read(10'd1, value);
                polls = polls + 1;
            end
            check(value, expected_status);
        end
    endtask
    task apply_reset;
        begin
            @(negedge clk); reset = 1; read = 0; write = 0;
            repeat (2) @(negedge clk);
            reset = 0;
        end
    endtask
    // Two immediate loads, arithmetic with rd==ra, then HALT.
    task arithmetic_test;
        input [3:0] opcode;
        input [31:0] a, b, expected;
        begin
            put_word(0, 32'h10000000); put_word(1, a);
            put_word(2, 32'h12000000); put_word(3, b);
            put_word(4, {opcode, 3'd0, 3'd0, 3'd1, 19'd0});
            put_word(5, 0);
            launch(6); wait_stop(2); expect_read(8, expected);
        end
    endtask

    initial begin
        apply_reset;
        expect_read(1, 0); expect_read(2, 0);
        for (i = 0; i < 8; i = i + 1) expect_read(8 + i, 0);

        // Manually encoded (7 + 3) * 2. R4 must hold 20.
        put_word(0, 32'h10000000); // LOAD_IMM R0
        put_word(1, 32'd7);
        put_word(2, 32'h12000000); // LOAD_IMM R1
        put_word(3, 32'd3);
        put_word(4, 32'h24080000); // ADD R2, R0, R1
        put_word(5, 32'h16000000); // LOAD_IMM R3
        put_word(6, 32'd2);
        put_word(7, 32'h48980000); // MUL R4, R2, R3
        put_word(8, 32'h00000000); // HALT
        launch(9);
        expect_read(1, 1);         // BUSY
        put_word(5, 32'hF0000000); // rejected during execution
        bus_write(2, 1);           // length change rejected while busy
        bus_write(0, 1);           // start ignored while busy
        wait_stop(2);
        expect_read(12, 20); expect_read(2, 9);
        repeat (3) @(negedge clk);
        expect_read(1, 2);         // DONE remains set
        bus_write(0, 0); expect_read(1, 2); // bit0=0 does not start
        bus_write(0, 1);           // restart same program; blocked write was discarded
        wait_stop(2); expect_read(12, 20);

        arithmetic_test(2, 32'hFFFFFFFF, 1, 0); // add wraps
        arithmetic_test(3, 0, 1, 32'hFFFFFFFF); // sub wraps
        arithmetic_test(4, 32'hFFFFFFFF, 2, 32'hFFFFFFFE); // low multiply bits
        arithmetic_test(4, 32'h80000000, 2, 0);
        arithmetic_test(2, 32'h20000000, 0, 32'h20000000); // opcode-like immediate
        arithmetic_test(3, 17, 5, 12);

        // Every register is writable, including R7.
        put_word(0, 32'h1E000000); put_word(1, 32'hDEADBEEF);
        put_word(2, 0); launch(3); wait_stop(2); expect_read(15, 32'hDEADBEEF);
        put_word(0, 0); launch(1); wait_stop(2);
        for (i = 0; i < 8; i = i + 1) expect_read(8 + i, 0); // START clears regs

        put_word(0, 32'hF0000000); launch(1); wait_stop(4); // bad opcode
        expect_read(1, 4); // ERROR sticky
        put_word(0, 32'h10000000); launch(1); wait_stop(4); // missing immediate
        put_word(0, 32'h20000000); launch(1); wait_stop(4); // no HALT
        launch(0); wait_stop(4);
        launch(513); wait_stop(4);
        launch(32'hFFFFFFFF); wait_stop(4);
        put_word(0, 0); launch(1); wait_stop(2); // restart clears ERROR

        // Full RAM: HALT at last location; no PC truncation at boundary.
        for (i = 0; i < 511; i = i + 1) put_word(i, 32'h20000000);
        put_word(511, 0); launch(512); wait_stop(2);
        put_word(511, 32'h20000000); launch(512); wait_stop(4); // reaches 512
        put_word(511, 32'h10000000); launch(512); wait_stop(4); // immediate beyond RAM

        // Reset during arithmetic execution, before completion is consumed.
        launch(512);
        wait (dut.scalar.state == 2'd1); // scalar ISSUE; global watchdog protects wait
        @(negedge clk); reset = 1;
        repeat (2) @(negedge clk);
        reset = 0;
        expect_read(1, 0); expect_read(2, 0);
        for (i = 0; i < 8; i = i + 1) expect_read(8 + i, 0);
        // Reload and execute after reset; no stale arithmetic completion.
        arithmetic_test(2, 7, 3, 10);
        expect_read(0, 0); expect_read(3, 0); expect_read(512, 0);
        @(negedge clk); read = 0;
        #1; check(readdata, 0);

        if (errors == 0) $display("PASS: controller_unit_tb, %0d checks", checks);
        else $display("FAIL: %0d errors in %0d checks", errors, checks);
        $finish;
    end
endmodule
