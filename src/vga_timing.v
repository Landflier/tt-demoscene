`default_nettype none

module vga_timing (
    input  wire clk,
    input  wire rst_n,
    output wire hsync,
    output wire vsync,
    output wire visible,
    output wire [9:0] pixel_x,
    output wire [9:0] pixel_y
);

    // 640x480 @ 60Hz timing parameters
    localparam H_VISIBLE    = 640;
    localparam H_FRONT      = 16;
    localparam H_SYNC       = 96;
    localparam H_BACK       = 48;
    localparam H_TOTAL      = 800;

    localparam V_VISIBLE    = 480;
    localparam V_FRONT      = 10;
    localparam V_SYNC       = 2;
    localparam V_BACK       = 33;
    localparam V_TOTAL      = 525;

    reg [9:0] h_counter;
    reg [9:0] v_counter;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            h_counter <= 0;
            v_counter <= 0;
        end else begin
            if (h_counter == H_TOTAL - 1) begin
                h_counter <= 0;
                if (v_counter == V_TOTAL - 1)
                    v_counter <= 0;
                else
                    v_counter <= v_counter + 1;
            end else begin
                h_counter <= h_counter + 1;
            end
        end
    end

    // Sync signals (active low)
    assign hsync = ~(h_counter >= (H_VISIBLE + H_FRONT) &&
                     h_counter <  (H_VISIBLE + H_FRONT + H_SYNC));
    assign vsync = ~(v_counter >= (V_VISIBLE + V_FRONT) &&
                     v_counter <  (V_VISIBLE + V_FRONT + V_SYNC));

    assign visible = (h_counter < H_VISIBLE) && (v_counter < V_VISIBLE);
    assign pixel_x = h_counter;
    assign pixel_y = v_counter;

endmodule
