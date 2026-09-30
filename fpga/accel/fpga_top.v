module fpga_top (
    input wire       MAX10_CLK1_50,
    input wire [1:0] KEY,
	 output wire [9:0] LEDR
);

    accel u0 (
        .clk_clk       (MAX10_CLK1_50),
        .reset_reset_n (KEY[0]),
		  .led_external_readdata (LEDR)
    );

endmodule