`default_nettype none
`timescale 1ns / 1ps

module tb_vga;

    reg clk;
    reg rst_n;
    wire [7:0] uo_out;

    tt_um_vga_demo dut (
        .ui_in   (8'b0),
        .uo_out  (uo_out),
        .uio_in  (8'b0),
        .uio_out (),
        .uio_oe  (),
        .ena     (1'b1),
        .clk     (clk),
        .rst_n   (rst_n)
    );

    // 25.175 MHz pixel clock -> ~39.7 ns period
    initial clk = 0;
    always #19.85 clk = ~clk;

    // Decode VGA PMOD signals
    wire hsync = uo_out[7];
    wire vsync = uo_out[3];
    wire [1:0] red   = {uo_out[0], uo_out[4]};  // {R1(MSB), R0(LSB)}
    wire [1:0] green = {uo_out[1], uo_out[5]};
    wire [1:0] blue  = {uo_out[2], uo_out[6]};

    // Timing measurement
    integer h_count, v_count;
    integer hsync_start, hsync_end, hsync_width;
    integer vsync_start, vsync_end, vsync_width;
    integer line_length;
    integer frame_lines;
    integer visible_pixels_in_line;
    integer visible_lines;
    integer errors;

    reg prev_hsync, prev_vsync;
    reg first_hsync_seen, first_vsync_seen;
    reg hsync_measured, vsync_measured;
    reg line_length_measured;
    reg frame_measured;
    reg visible_checked;

    // Track pixel activity
    integer total_nonblack_pixels;

    initial begin
        $dumpfile("tb_vga.vcd");
        $dumpvars(0, tb_vga);

        errors = 0;
        h_count = 0;
        v_count = 0;
        hsync_start = 0;
        hsync_end = 0;
        hsync_width = 0;
        vsync_start = 0;
        vsync_end = 0;
        vsync_width = 0;
        line_length = 0;
        frame_lines = 0;
        visible_pixels_in_line = 0;
        visible_lines = 0;
        prev_hsync = 1;
        prev_vsync = 1;
        first_hsync_seen = 0;
        first_vsync_seen = 0;
        hsync_measured = 0;
        vsync_measured = 0;
        line_length_measured = 0;
        frame_measured = 0;
        visible_checked = 0;
        total_nonblack_pixels = 0;

        // Reset
        rst_n = 0;
        #200;
        rst_n = 1;

        // Run for 2 full frames (2 * 800 * 525 = 840000 clocks)
        repeat (840000 * 2) begin
            @(posedge clk);
            h_count = h_count + 1;

            // Count non-black visible pixels
            if (hsync && vsync && (red != 0 || green != 0 || blue != 0))
                total_nonblack_pixels = total_nonblack_pixels + 1;

            // Detect hsync falling edge (active low sync pulse start)
            if (prev_hsync && !hsync) begin
                if (first_hsync_seen && !line_length_measured) begin
                    line_length = h_count;
                    line_length_measured = 1;
                    $display("INFO: Line length = %0d pixels", line_length);
                    if (line_length != 800) begin
                        $display("ERROR: Expected 800 pixels per line, got %0d", line_length);
                        errors = errors + 1;
                    end
                end
                if (first_hsync_seen)
                    h_count = 0;
                first_hsync_seen = 1;
                hsync_start = h_count;
                v_count = v_count + 1;
            end

            // Detect hsync rising edge (sync pulse end)
            if (!prev_hsync && hsync) begin
                if (!hsync_measured && first_hsync_seen) begin
                    hsync_width = h_count - hsync_start;
                    hsync_measured = 1;
                    $display("INFO: HSYNC pulse width = %0d pixels", hsync_width);
                    if (hsync_width != 96) begin
                        $display("ERROR: Expected HSYNC width 96, got %0d", hsync_width);
                        errors = errors + 1;
                    end
                end
            end

            // Detect vsync falling edge
            if (prev_vsync && !vsync) begin
                if (first_vsync_seen && !frame_measured) begin
                    frame_lines = v_count;
                    frame_measured = 1;
                    $display("INFO: Frame height = %0d lines", frame_lines);
                    if (frame_lines != 525) begin
                        $display("ERROR: Expected 525 lines per frame, got %0d", frame_lines);
                        errors = errors + 1;
                    end
                end
                first_vsync_seen = 1;
                v_count = 0;
            end

            // Detect vsync rising edge
            if (!prev_vsync && vsync) begin
                if (!vsync_measured && first_vsync_seen) begin
                    vsync_width = v_count;
                    vsync_measured = 1;
                    $display("INFO: VSYNC pulse width = %0d lines", vsync_width);
                    if (vsync_width != 2) begin
                        $display("ERROR: Expected VSYNC width 2 lines, got %0d", vsync_width);
                        errors = errors + 1;
                    end
                end
            end

            // Check blanking: RGB must be 0 during sync pulses
            if (!hsync || !vsync) begin
                if (red != 0 || green != 0 || blue != 0) begin
                    if (!visible_checked) begin
                        $display("ERROR: Non-zero RGB during blanking at time %0t", $time);
                        errors = errors + 1;
                        visible_checked = 1;
                    end
                end
            end

            prev_hsync = hsync;
            prev_vsync = vsync;
        end

        // Check that we saw actual pixel data
        $display("INFO: Total non-black visible pixels = %0d", total_nonblack_pixels);
        if (total_nonblack_pixels == 0) begin
            $display("ERROR: No visible pixel data generated");
            errors = errors + 1;
        end

        $display("");
        if (errors == 0)
            $display("PASS: All VGA timing checks passed");
        else
            $display("FAIL: %0d error(s) detected", errors);

        $finish;
    end

endmodule
