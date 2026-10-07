// Controller-facing scalar engine. This REPLACES the old scalar_unit.
// Accept start only while busy=0. Capture operands/op on the accepting edge.
// result_valid pulses for one cycle at completion; result holds until the
// next completion or reset. Reset aborts any operation. All use one clock.
module scalar_unit (
    input wire clk,
    input wire reset,                  // synchronous, active high
    input wire start,
    input wire [31:0] a_in,
    input wire [31:0] b_in,
    input wire [1:0] op,               // 00 ADD, 01 SUB, 10 MUL; 11 reserved
    output wire busy,
    output reg [31:0] result,
    output reg result_valid
);
    localparam IDLE = 2'd0, ISSUE = 2'd1, WAIT_RESULT = 2'd2;
    reg [1:0] state;
    reg [31:0] a_reg, b_reg;
    reg [1:0] op_reg;
    wire [31:0] arithmetic_result;
    wire arithmetic_valid;

    assign busy = (state != IDLE);

    scalar_arith_unit arithmetic (
        .clk(clk), .reset(reset), .a_in(a_reg), .b_in(b_reg), .op(op_reg),
        .input_valid(!reset && (state == ISSUE)),
        .result(arithmetic_result), .result_valid(arithmetic_valid)
    );

    always @(posedge clk) begin
        if (reset) begin
            state <= IDLE;
            a_reg <= 0; b_reg <= 0; op_reg <= 0;
            result <= 0; result_valid <= 0;
        end else begin
            result_valid <= 0;
            case (state)
                IDLE: begin
                    if (start) begin
                        a_reg <= a_in;
                        b_reg <= b_in;
                        op_reg <= op;
                        state <= ISSUE;
                    end
                end
                ISSUE: state <= WAIT_RESULT;
                WAIT_RESULT: begin
                    if (arithmetic_valid) begin
                        result <= arithmetic_result;
                        result_valid <= 1;
                        state <= IDLE;
                    end
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule
