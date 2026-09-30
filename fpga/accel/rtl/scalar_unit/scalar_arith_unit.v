module scalar_arith_unit (
    input wire          clk,
    input wire          reset,

    input wire [31:0]   a_in,
    input wire [31:0]   b_in,
    input wire [1:0]    op,
    input wire          input_valid,

    output reg [31:0]   result,
    output reg          result_valid
);

    always @(posedge clk) begin
        if (reset) begin
            result          <= 32'b0;
            result_valid    <= 1'b0;
        end
        else begin
            // default
            result_valid <= 1'b0;

            if (input_valid) begin
                case (op)
                    2'b00: result <= a_in + b_in;
                    2'b01: result <= a_in - b_in;
                    2'b10: result <= a_in * b_in;
                    default: result <= 32'b0;
                endcase

                result_valid <= 1'b1;
            end
        end
    end

endmodule