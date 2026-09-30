module led_animator (
    input wire          clk,
    input wire          reset,
    output reg [9:0]    led
);

// 50 MHz clock
// 5M cycles = 0.1 seconds
reg [23:0] counter;

always @(posedge clk) begin
    if (reset) begin
        counter <= 24'b0;
        led     <= 10'b0000000001;
    end
    else begin
        if (counter == 24'd4_999_999) begin
            counter <= 24'b0;

            // restart at LEDR0 after reaching LEDR9
            if (led == 10'b1000000000)
                led <= 10'b0000000001;
            else
                led <= led << 1;
        end
        else begin
            counter <= counter + 1'b1;
        end
    end
end

endmodule