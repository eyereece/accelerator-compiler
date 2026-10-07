// 512 x 32-bit instruction RAM. Both ports use the same clock.
// Addresses are WORD indices (0..511), not byte addresses.
// The top-level custom controller drives the load signals.
module instruction_ram (
    input  wire        clk,
    input  wire        reset_n,
    input  wire        busy,

    input  wire        load_write,
    input  wire [8:0]  load_addr,
    input  wire [31:0] load_data,

    input  wire        fetch_enable,
    input  wire [8:0]  fetch_addr,
    output reg  [31:0] fetch_data
);
    reg [31:0] mem [0:511];

    // Ignored writes are discarded, not queued for later.
    always @(posedge clk) begin
        if (reset_n && load_write && !busy)
            mem[load_addr] <= load_data;
    end

    // Address/enable are sampled at the rising edge; data updates after it.
    // Another clocked module can capture that data at the NEXT rising edge.
    // When disabled or in reset, fetch_data holds its previous value.
    // RAM contents and fetch_data are intentionally not reset/initialized.
    always @(posedge clk) begin
        if (reset_n && fetch_enable)
            fetch_data <= mem[fetch_addr];
    end
endmodule
