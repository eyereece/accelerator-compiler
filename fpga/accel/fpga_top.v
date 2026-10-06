module fpga_top (
    input  wire        MAX10_CLK1_50,
    input  wire [1:0]  KEY,
    output wire [9:0]  LEDR,

    output wire [12:0] DRAM_ADDR,
    output wire [1:0]  DRAM_BA,
    output wire        DRAM_CAS_N,
    output wire        DRAM_CKE,
    output wire        DRAM_CLK,
    output wire        DRAM_CS_N,
    inout  wire [15:0] DRAM_DQ,
    output wire        DRAM_LDQM,
    output wire        DRAM_UDQM,
    output wire        DRAM_RAS_N,
    output wire        DRAM_WE_N
);

    accel u0 (
        .clk_clk               (MAX10_CLK1_50),
        .reset_reset_n         (KEY[0]),
        .led_external_readdata (LEDR),

        .sdram_clk_clk         (DRAM_CLK),
        .sdram_addr            (DRAM_ADDR),
        .sdram_ba              (DRAM_BA),
        .sdram_cas_n           (DRAM_CAS_N),
        .sdram_cke             (DRAM_CKE),
        .sdram_cs_n            (DRAM_CS_N),
        .sdram_dq              (DRAM_DQ),
        .sdram_dqm             ({DRAM_UDQM, DRAM_LDQM}),
        .sdram_ras_n           (DRAM_RAS_N),
        .sdram_we_n            (DRAM_WE_N)
    );

endmodule