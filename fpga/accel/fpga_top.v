module fpga_top (
    input wire       MAX10_CLK1_50,
    input wire [1:0] KEY
);

    accel u0 (
        .clk_clk       (MAX10_CLK1_50),
        .reset_reset_n (KEY[0])
    );

endmodule