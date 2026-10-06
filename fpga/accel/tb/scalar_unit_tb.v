`timescale 1ns/1ps

module scalar_unit_tb;
    localparam [2:0] A=3'd0, B=3'd1, OP=3'd2, START=3'd3,
                     RESULT=3'd4, STATUS=3'd5, ACK=3'd6;
    reg clk=0;
    reg reset=1;
    reg [2:0] address=0;
    reg read=0, write=0;
    reg [31:0] writedata=0;
    wire [31:0] readdata;
    integer checks=0, transactions=0;
    integer op_counts[0:2];
    integer i, seed;
    reg [31:0] rng_state, ra, rb;
    reg [1:0] random_op;
    integer gap;

    scalar_unit dut (.clk(clk), .reset(reset), .address(address),
        .read(read), .write(write), .writedata(writedata), .readdata(readdata));
    always #10 clk=~clk; // 50 MHz

    // xorshift32 algorithm
    function automatic [31:0] next_random(input dummy);
        reg [31:0] x;
        begin
            x=rng_state;
            x=x^(x<<13);
            x=x^(x>>17);
            x=x^(x<<5);
            rng_state=x;
            next_random=x;
        end
    endfunction

    task automatic check_value(input [31:0] actual, expected,
                               input [8*96-1:0] label_text);
        begin
            checks=checks+1;
            if (actual !== expected) begin
                $display("FAIL %0s: expected=%08h actual=%08h time=%0t",
                         label_text, expected, actual, $time);
                $finish;
            end
        end
    endtask

    // Drive on falling edges; the DUT samples on rising edges.
    task automatic mm_write(input [2:0] addr, input [31:0] value);
        begin
            @(negedge clk);
            address=addr; writedata=value; read=0; write=1;
            @(negedge clk);
            write=0;
        end
    endtask

    task automatic expect_read(input [2:0] addr, input [31:0] expected,
                               input [8*96-1:0] label_text);
        begin
            @(negedge clk);
            address=addr; read=1; write=0;
            #1; // combinational read mux settles
            check_value(readdata, expected, label_text);
            @(negedge clk);
            read=0;
            #1;
            check_value(readdata, 0, "read disabled returns zero");
        end
    endtask

    task automatic apply_reset;
        begin
            @(negedge clk);
            reset=1; read=0; write=0; address=0; writedata=0;
            @(posedge clk);
            @(negedge clk); reset=0;
            expect_read(A, 0, "reset A");
            expect_read(B, 0, "reset B");
            expect_read(OP, 0, "reset OP");
            expect_read(RESULT, 0, "reset RESULT");
            expect_read(STATUS, 0, "reset STATUS");
        end
    endtask

    task automatic run_operation(input [31:0] av, bv,
                                 input [1:0] opcode, input integer hold_cycles);
        reg [31:0] expected;
        begin
            case (opcode)
                0: expected=av+bv;
                1: expected=av-bv;
                2: expected=av*bv;
                default: begin
                    $display("FAIL: Testbench generated reserved opcode");
                    $finish;
                end
            endcase
            expect_read(STATUS, 0, "idle status before request");
            mm_write(A, av);
            mm_write(B, bv);
            mm_write(OP, {30'b0,opcode});
            expect_read(A, av, "A readback");
            expect_read(B, bv, "B readback");
            expect_read(OP, {30'b0,opcode}, "OP readback");

            // First rising edge accepts START and updates arithmetic outputs.
            @(negedge clk);
            address=START; writedata=1; read=0; write=1;
            @(posedge clk); #1;
            address=STATUS; read=1; write=0;
            #1;
            check_value(readdata, 0, "not captured on START edge");
            // Wrapper captures those outputs at the next rising edge.
            @(posedge clk); #1;
            check_value(readdata, 1, "available on second rising edge");
            @(negedge clk); read=0;

            expect_read(RESULT, expected, "arithmetic result");
            repeat (hold_cycles) @(negedge clk);
            expect_read(STATUS, 1, "status persists until ACK");
            expect_read(RESULT, expected, "result remains stable before ACK");
            mm_write(ACK, 1);
            expect_read(STATUS, 0, "ACK clears status");
            expect_read(RESULT, expected, "ACK preserves result register");
            transactions=transactions+1;
            op_counts[opcode]=op_counts[opcode]+1;
        end
    endtask

    initial begin
        seed=12345;
        if ($value$plusargs("SEED=%d", seed)) begin end
        rng_state=seed;
        if (rng_state==0) rng_state=32'h1; // xorshift cannot use zero state
        for (i=0; i<3; i=i+1) op_counts[i]=0;
        $display("Starting scalar_unit tests, seed=%0d", seed);
        apply_reset();
        expect_read(START, 0, "START read returns zero");
        expect_read(ACK, 0, "ACK read returns zero");
        expect_read(3'd7, 0, "unmapped read returns zero");
        mm_write(OP, 32'hfffffffe);
        expect_read(OP, 2, "only low two OP bits stored");

        run_operation(7, 3, 0, 0);
        run_operation(7, 3, 1, 1);
        run_operation(7, 3, 2, 2);
        run_operation(0, 0, 0, 0);
        run_operation(32'hffffffff, 1, 0, 3); // addition wraps to zero
        run_operation(32'h7fffffff, 1, 0, 1);
        run_operation(0, 1, 1, 2); // subtraction wraps to ffffffff
        run_operation(32'h80000000, 1, 1, 0);
        run_operation(32'hffffffff, 2, 2, 3);
        run_operation(32'h00010000, 32'h00010000, 2, 1); // low product=0
        run_operation(32'hffffffff, 32'hffffffff, 2, 2);
        run_operation(0, 32'hffffffff, 2, 0);

        for (i=0; i<300; i=i+1) begin
            ra=next_random(1'b0); rb=next_random(1'b0);
            random_op=next_random(1'b0)%3; // constrain to ADD, SUB, MUL
            gap=next_random(1'b0)%6; // constrain idle/hold delays to 0..5 cycles
            repeat (gap) @(negedge clk);
            run_operation(ra, rb, random_op, gap);
        end

        // Reset with an unacknowledged result, then prove recovery.
        mm_write(A, 9); mm_write(B, 4); mm_write(OP, 0);
        mm_write(START, 1);
        expect_read(STATUS, 1, "pending result before reset");
        apply_reset();
        run_operation(9, 4, 0, 0);
        $display("PASS: %0d transactions, %0d checks; ADD=%0d SUB=%0d MUL=%0d; seed=%0d",
                 transactions, checks, op_counts[0], op_counts[1], op_counts[2], seed);
        $finish;
    end

    // Make sure a stalled test cannot hang indefinitely.
    initial begin
        #2000000;
        $display("FAIL: Global testbench timeout");
        $finish;
    end
endmodule
