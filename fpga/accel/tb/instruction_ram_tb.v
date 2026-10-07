`timescale 1ns/1ps
module instruction_ram_tb;
    reg clk = 0;
    always #10 clk = ~clk; // 1/50MHz = 20ns for 1 full clock cycle
    reg reset_n = 0;
    reg busy = 0;
    reg load_write = 0;
    reg [8:0] load_addr = 0;
    reg [31:0] load_data = 0;
    reg fetch_enable = 0;
    reg [8:0] fetch_addr = 0;
    wire [31:0] fetch_data;
    integer i;
    integer checks = 0;
    integer errors = 0;
    reg [31:0] held;

    instruction_ram dut (
        .clk(clk), .reset_n(reset_n), .busy(busy),
        .load_write(load_write), .load_addr(load_addr), .load_data(load_data),
        .fetch_enable(fetch_enable), .fetch_addr(fetch_addr),
        .fetch_data(fetch_data)
    );

    task check_data;
        input [31:0] expected;
        begin
            checks = checks + 1;
            if (fetch_data !== expected) begin
                errors = errors + 1;
                $display("FAIL check %0d: got %h expected %h", checks, fetch_data, expected);
            end
        end
    endtask

    task write_word;
        input [8:0] addr;
        input [31:0] value;
        begin
            @(negedge clk);
            load_write = 1; load_addr = addr; load_data = value;
            @(negedge clk);
            load_write = 0;
        end
    endtask

    task read_word;
        input [8:0] addr;
        input [31:0] expected;
        begin
            @(negedge clk);
            fetch_enable = 1; fetch_addr = addr;
            @(posedge clk); #1;
            check_data(expected);
            @(negedge clk);
            fetch_enable = 0;
        end
    endtask

    initial begin
        repeat (2) @(negedge clk);
        reset_n = 1;
        // Exercise every location, including both boundaries.
        for (i = 0; i < 512; i = i + 1)
            write_word(i, 32'hA5000000 ^ i);
        busy = 1;
        for (i = 0; i < 512; i = i + 1)
            read_word(i, 32'hA5000000 ^ i);

        // Busy rejects a write; it is not deferred until idle.
        write_word(9'd17, 32'hDEADBEEF);    // unsuccessful write
        busy = 0;
        read_word(9'd17, 32'hA5000011);     // reads previous write
        write_word(9'd17, 32'hFFFFFFFF);    // successful
        read_word(9'd17, 32'hFFFFFFFF);     // reads the write from previous line

        // Output holds when read disabled, even if address changes.
        held = fetch_data;  // save current output; fetch_enable is 0 from read_word
        fetch_addr = 9'd0;  // change addr wo enabling a read
        @(posedge clk); #1; check_data(held);   // output still hold the saved value

        // Output must not change before the sampling edge.
        @(negedge clk);
        fetch_enable = 1; fetch_addr = 9'd0;    // request read of word 0
        #1; check_data(held);   // remain unchanged
        @(posedge clk); #1; check_data(32'hA5000000);   // output should contain word 0 now
        @(negedge clk); fetch_enable = 0;   // disable further reads

        // Reset blocks writes/reads and preserves previously stored words.
        reset_n = 0;
        fetch_enable = 1; fetch_addr = 9'd17;  
        write_word(9'd17, 32'h12345678);    // unsuccessful write bc reset_n == 0
        check_data(32'hA5000000);   // read was blocked, output still holds prev val
        fetch_enable = 0;   // disable read request
        reset_n = 1;    // release reset
        read_word(9'd17, 32'hFFFFFFFF);// ori value remains; reset/write didnt change it

        if (errors == 0)
            $display("PASS: %0d checks", checks);
        else
            $display("FAIL: %0d errors in %0d checks", errors, checks);
        $finish;
    end
endmodule
