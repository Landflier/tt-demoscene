`default_nettype none

module tt_um_vga_demo (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

    wire hsync, vsync, visible;
    wire [9:0] pixel_x, pixel_y;
    wire [1:0] red, green, blue;

    vga_timing vga_timing_inst (
        .clk     (clk),
        .rst_n   (rst_n),
        .hsync   (hsync),
        .vsync   (vsync),
        .visible (visible),
        .pixel_x (pixel_x),
        .pixel_y (pixel_y)
    );

    pixel_generator pixel_gen_inst (
        .clk     (clk),
        .rst_n   (rst_n),
        .visible (visible),
        .pixel_x (pixel_x),
        .pixel_y (pixel_y),
        .red     (red),
        .green   (green),
        .blue    (blue)
    );

    // Tiny VGA PMOD pin mapping
    // uo_out = {hsync, b0, g0, r0, vsync, b1, g1, r1}
    assign uo_out = {hsync, blue[0], green[0], red[0], vsync, blue[1], green[1], red[1]};

    // QSPI PMOD — unused for now, directly active I/O all as inputs
    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0;

endmodule
