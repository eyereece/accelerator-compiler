module scalar_unit (
    input wire          clk,
    input wire          reset,

    input wire [2:0]    address,
    input wire          read,
    input wire          write,
    input wire [31:0]   writedata,
    output reg [31:0]   readdata
);

    // Registers that hold valus sent by Nios V
    reg [31:0] a_reg;
    reg [31:0] b_reg;
    reg [1:0] op_reg;
    reg [31:0] result_reg;
    reg         result_available;

    wire        input_valid;

    // Result produced by scalar_unit
    wire [31:0] result_wire;
    wire        result_valid_wire;

    assign input_valid = write && (address == 3'b011);

    // -------------------------------------
    // RESULT
    // -------------------------------------
    always @(posedge clk) begin
        if (reset) begin
            result_reg      <= 32'b0;
            result_available <= 1'b0;
        end
        else if (result_valid_wire) begin
            result_reg          <= result_wire;
            result_available    <= 1'b1;
        end
    end

    // -------------------------------------
    // WRITE
    // -------------------------------------
    always @(posedge clk) begin
        if (reset) begin
            a_reg <= 32'b0;
            b_reg <= 32'b0;
            op_reg <= 2'b0;
        end
        else if (write) begin
            case (address)
                3'b000: a_reg <= writedata;
                3'b001: b_reg <= writedata;
                3'b010: op_reg <= writedata[1:0];
                default: ;
            endcase
        end
    end

    // -------------------------------------
    // READ
    // -------------------------------------
    always @(*) begin
        if (read) begin
            case (address)
                3'b000: readdata = a_reg;
                3'b001: readdata = b_reg;
                3'b010: readdata = {30'b0, op_reg};
                3'b100: readdata = result_reg;
                3'b101: readdata = {31'b0, result_available};
                default: readdata = 32'b0;
            endcase
        end
        else begin
            readdata = 32'b0;
        end
    end

    // -------------------------------------
    // ARITHMETIC UNIT MAPPING
    // -------------------------------------
    scalar_arith_unit u_scalar_arith_unit (
        .clk            (clk),
        .reset          (reset),
        .a_in           (a_reg),
        .b_in           (b_reg),
        .op             (op_reg),
        .input_valid    (input_valid),
        .result         (result_wire),
        .result_valid   (result_valid_wire)
    );
endmodule