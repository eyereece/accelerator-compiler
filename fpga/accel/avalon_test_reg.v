module avalon_test_reg (
    input wire clk,
    input wire reset,

    input wire read,
    input wire write,
    input wire [31:0] writedata,
    output wire [31:0] readdata
);

    reg [31:0] test_reg;

    // write register
    always @(posedge clk) begin
        if (reset)
            test_reg <= 32'b0;
        else if (write)
            test_reg <= writedata;
    end

    assign readdata = read ? test_reg : 32'b0;
endmodule