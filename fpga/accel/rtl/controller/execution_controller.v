// Phase-0 ISA: 0 HALT, 1 LOAD_IMM (next word), 2 ADD, 3 SUB, 4 MUL.
// Fields: opcode[31:28], rd[27:25], ra[24:22], rb[21:19].
// Unused fields are ignored. All registers are writable; arithmetic wraps.
module execution_controller (
    input wire clk,
    input wire reset,                  // synchronous, active high
    input wire start,                  // accepted only when idle
    input wire [31:0] program_words,
    output reg busy,
    output reg done,
    output reg error,
    output wire fetch_enable,
    output wire [8:0] fetch_addr,
    input wire [31:0] fetch_data,
    input wire [2:0] reg_read_addr,
    output wire [31:0] reg_read_data,

    // Request/result interface to the separate scalar engine.
    output wire scalar_start,
    output reg [31:0] scalar_a,
    output reg [31:0] scalar_b,
    output reg [1:0] scalar_op,
    input wire scalar_busy,
    input wire [31:0] scalar_result,
    input wire scalar_result_valid
);
    localparam IDLE = 4'd0, FETCH_REQUEST = 4'd1, FETCH_CAPTURE = 4'd2,
               DECODE = 4'd3, IMM_REQUEST = 4'd4, IMM_CAPTURE = 4'd5,
               ARITH_ISSUE = 4'd6, ARITH_WAIT = 4'd7, WRITEBACK = 4'd8;
    reg [3:0] state;
    // Ten bits allow the end sentinel 512 without wrapping back to zero.
    reg [9:0] pc;
    reg [9:0] limit_words;
    reg [31:0] instruction;
    reg [31:0] registers [0:7];
    reg [2:0] destination;
    reg [31:0] pending_result;
    integer i;

    assign fetch_addr = pc[8:0];
    assign fetch_enable = !reset && (pc < limit_words) &&
                         ((state == FETCH_REQUEST) || (state == IMM_REQUEST));
    assign reg_read_data = registers[reg_read_addr];

    // Hold operands stable while waiting for an idle engine. A request is
    // accepted at a rising edge with scalar_start=1 and scalar_busy=0.
    assign scalar_start = !reset && (state == ARITH_ISSUE) && !scalar_busy;

    always @(posedge clk) begin
        if (reset) begin
            state <= IDLE;
            pc <= 0; limit_words <= 0; instruction <= 0;
            destination <= 0; scalar_a <= 0; scalar_b <= 0;
            scalar_op <= 0; pending_result <= 0;
            busy <= 0; done <= 0; error <= 0;
            for (i = 0; i < 8; i = i + 1) registers[i] <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        pc <= 0; done <= 0; error <= 0;
                        for (i = 0; i < 8; i = i + 1) registers[i] <= 0;
                        if ((program_words == 0) || (program_words > 512)) begin
                            busy <= 0; error <= 1;
                        end else begin
                            limit_words <= program_words[9:0];
                            busy <= 1; state <= FETCH_REQUEST;
                        end
                    end
                end
                FETCH_REQUEST: begin
                    if (pc >= limit_words) begin
                        busy <= 0; error <= 1; state <= IDLE;
                    end else begin
                        // RAM samples address at this edge. Capture next edge.
                        state <= FETCH_CAPTURE;
                    end
                end
                FETCH_CAPTURE: begin
                    instruction <= fetch_data;
                    state <= DECODE;
                end
                DECODE: begin
                    case (instruction[31:28])
                        4'h0: begin
                            busy <= 0; done <= 1; state <= IDLE;
                        end
                        4'h1: begin
                            destination <= instruction[27:25];
                            pc <= pc + 10'd1;
                            state <= IMM_REQUEST;
                        end
                        4'h2, 4'h3, 4'h4: begin
                            destination <= instruction[27:25];
                            scalar_a <= registers[instruction[24:22]];
                            scalar_b <= registers[instruction[21:19]];
                            case (instruction[31:28])
                                4'h2: scalar_op <= 2'b00;
                                4'h3: scalar_op <= 2'b01;
                                4'h4: scalar_op <= 2'b10;
                            endcase
                            state <= ARITH_ISSUE;
                        end
                        default: begin
                            busy <= 0; error <= 1; state <= IDLE;
                        end
                    endcase
                end
                IMM_REQUEST: begin
                    if (pc >= limit_words) begin
                        busy <= 0; error <= 1; state <= IDLE;
                    end else state <= IMM_CAPTURE;
                end
                IMM_CAPTURE: begin
                    // Immediate bits are data regardless of opcode-like patterns.
                    pending_result <= fetch_data;
                    state <= WRITEBACK;
                end
                ARITH_ISSUE: begin
                    if (!scalar_busy) state <= ARITH_WAIT;
                end
                ARITH_WAIT: begin
                    if (scalar_result_valid) begin
                        pending_result <= scalar_result;
                        state <= WRITEBACK;
                    end
                end
                WRITEBACK: begin
                    registers[destination] <= pending_result;
                    pc <= pc + 10'd1;
                    state <= FETCH_REQUEST;
                end
                default: begin
                    busy <= 0; done <= 0; error <= 1; state <= IDLE;
                end
            endcase
        end
    end
endmodule
