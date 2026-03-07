`default_nettype none

module pixel_generator (
    input  wire clk,
    input  wire rst_n,
    input  wire visible,
    input  wire [9:0] pixel_x,
    input  wire [9:0] pixel_y,
    output wire [1:0] red,
    output wire [1:0] green,
    output wire [1:0] blue
);

    reg [7:0] frame_counter;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            frame_counter <= 0;
        else if (pixel_x == 0 && pixel_y == 0)
            frame_counter <= frame_counter + 1;
    end

    // XOR plasma pattern — purely combinational from (x, y, frame)
    wire [7:0] px = pixel_x[7:0] + frame_counter;
    wire [7:0] py = pixel_y[7:0];
    wire [7:0] pattern = px ^ py;

    assign red   = visible ? pattern[1:0] : 2'b00;
    assign green = visible ? pattern[3:2] : 2'b00;
    assign blue  = visible ? pattern[5:4] : 2'b00;

endmodule
