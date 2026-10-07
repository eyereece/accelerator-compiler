// Avalon-MM, 32-bit full-word accesses, WORD addressing, no wait states.
// Byte offsets: 0x000 START (bit0); 0x004 STATUS (busy/done/error bits0/1/2);
// 0x008 PROGRAM_WORDS; 0x020..0x03c R0..R7; 0x800..0xffc instruction RAM.
// Configure addressUnits=WORDS, readLatency=0 in the eventual PD component.
// Reads of unmapped/write-only addresses return zero. No byteenable support:
// software must use aligned 32-bit accesses. Busy writes are discarded.
module controller_unit (
    input wire clk,
    input wire reset,
    input wire [9:0] address,
    input wire read,
    input wire write,
    input wire [31:0] writedata,
    output reg [31:0] readdata
);
    reg [31:0] program_words;
    wire busy, done, error;
    wire scalar_start, scalar_busy, scalar_result_valid;
    wire [31:0] scalar_a, scalar_b, scalar_result;
    wire [1:0] scalar_op;
    wire fetch_enable;
    wire [8:0] fetch_addr;
    wire [31:0] fetch_data, reg_read_data;
    wire start = !reset && write && !busy &&
                 (address == 10'd0) && writedata[0];

    always @(posedge clk) begin
        if (reset) program_words <= 0;
        else if (write && !busy && (address == 10'd2))
            program_words <= writedata;
    end

    instruction_ram program_memory (
        .clk(clk), .reset_n(!reset), .busy(busy),
        .load_write(write && address[9]),
        .load_addr(address[8:0]), .load_data(writedata),
        .fetch_enable(fetch_enable), .fetch_addr(fetch_addr),
        .fetch_data(fetch_data)
    );

    execution_controller controller (
        .clk(clk), .reset(reset), .start(start), .program_words(program_words),
        .busy(busy), .done(done), .error(error),
        .fetch_enable(fetch_enable), .fetch_addr(fetch_addr),
        .fetch_data(fetch_data), .reg_read_addr(address[2:0]),
        .reg_read_data(reg_read_data),
        .scalar_start(scalar_start), .scalar_a(scalar_a), .scalar_b(scalar_b),
        .scalar_op(scalar_op), .scalar_busy(scalar_busy),
        .scalar_result(scalar_result), .scalar_result_valid(scalar_result_valid)
    );

    // Sibling engine: owns its operand capture and arithmetic handshake.
    // Future vector_unit connects here through its own request/result wires.
    scalar_unit scalar (
        .clk(clk), .reset(reset), .start(scalar_start),
        .a_in(scalar_a), .b_in(scalar_b), .op(scalar_op),
        .busy(scalar_busy), .result(scalar_result),
        .result_valid(scalar_result_valid)
    );

    always @(*) begin
        readdata = 32'b0;
        if (read) begin
            case (address)
                10'd1: readdata = {29'b0, error, done, busy};
                10'd2: readdata = program_words;
                10'd8, 10'd9, 10'd10, 10'd11,
                10'd12, 10'd13, 10'd14, 10'd15: readdata = reg_read_data;
                default: readdata = 32'b0;
            endcase
        end
    end
endmodule
