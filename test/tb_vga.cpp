#include <cstdio>
#include <cstdlib>
#include "Vtt_um_vga_demo.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);
    Verilated::traceEverOn(true);

    Vtt_um_vga_demo *dut = new Vtt_um_vga_demo;
    VerilatedVcdC *trace = new VerilatedVcdC;
    dut->trace(trace, 5);
    trace->open("tb_vga.vcd");

    int errors = 0;
    uint64_t sim_time = 0;

    // Initialize
    dut->clk = 0;
    dut->rst_n = 0;
    dut->ena = 1;
    dut->ui_in = 0;
    dut->uio_in = 0;

    // Reset for 10 cycles
    for (int i = 0; i < 20; i++) {
        dut->clk = !dut->clk;
        dut->eval();
        trace->dump(sim_time++);
    }
    dut->rst_n = 1;

    // Decode PMOD signals from uo_out
    auto get_hsync = [&]() -> int { return (dut->uo_out >> 7) & 1; };
    auto get_vsync = [&]() -> int { return (dut->uo_out >> 3) & 1; };
    auto get_rgb   = [&]() -> int {
        int r1 = (dut->uo_out >> 0) & 1;
        int r0 = (dut->uo_out >> 4) & 1;
        int g1 = (dut->uo_out >> 1) & 1;
        int g0 = (dut->uo_out >> 5) & 1;
        int b1 = (dut->uo_out >> 2) & 1;
        int b0 = (dut->uo_out >> 6) & 1;
        return (r1 << 5) | (r0 << 4) | (g1 << 3) | (g0 << 2) | (b1 << 1) | b0;
    };

    // Run 2 full frames: 2 * 800 * 525 = 840000 clocks
    // Each clock = 2 half-cycles
    int total_clocks = 840000 * 2;

    int prev_hsync = 1, prev_vsync = 1;
    int h_count = 0, v_count = 0;
    int line_length = -1, frame_lines = -1;
    int hsync_width = -1, vsync_width = -1;
    int hsync_start = 0;
    bool first_hsync = false, first_vsync = false;
    bool hsync_measured = false, vsync_measured = false;
    bool line_measured = false, frame_measured = false;
    int blanking_violations = 0;
    long total_nonblack = 0;

    for (int i = 0; i < total_clocks; i++) {
        dut->clk = !dut->clk;
        dut->eval();
        trace->dump(sim_time++);

        // Only sample on rising edge
        if (dut->clk != 1) continue;

        int hs = get_hsync();
        int vs = get_vsync();
        int rgb = get_rgb();

        h_count++;

        // Count non-black visible pixels
        if (hs && vs && rgb != 0)
            total_nonblack++;

        // Check blanking: RGB must be 0 during sync
        if (!hs || !vs) {
            if (rgb != 0)
                blanking_violations++;
        }

        // HSYNC falling edge (start of sync pulse)
        if (prev_hsync && !hs) {
            if (first_hsync) {
                if (!line_measured) {
                    line_length = h_count;
                    line_measured = true;
                }
                h_count = 0;
            }
            first_hsync = true;
            h_count = 0;
            hsync_start = 0;
            v_count++;
        }

        // HSYNC rising edge (end of sync pulse)
        if (!prev_hsync && hs) {
            if (!hsync_measured && first_hsync) {
                hsync_width = h_count - hsync_start;
                hsync_measured = true;
            }
        }

        // VSYNC falling edge
        if (prev_vsync && !vs) {
            if (first_vsync && !frame_measured) {
                frame_lines = v_count;
                frame_measured = true;
            }
            first_vsync = true;
            v_count = 0;
        }

        // VSYNC rising edge
        if (!prev_vsync && vs) {
            if (!vsync_measured && first_vsync) {
                vsync_width = v_count;
                vsync_measured = true;
            }
        }

        prev_hsync = hs;
        prev_vsync = vs;
    }

    // Report results
    printf("=== VGA Timing Verification ===\n");

    printf("Line length:     %d pixels (expected 800)\n", line_length);
    if (line_length != 800) { printf("  FAIL\n"); errors++; }
    else printf("  PASS\n");

    printf("HSYNC width:     %d pixels (expected 96)\n", hsync_width);
    if (hsync_width != 96) { printf("  FAIL\n"); errors++; }
    else printf("  PASS\n");

    printf("Frame height:    %d lines  (expected 525)\n", frame_lines);
    if (frame_lines != 525) { printf("  FAIL\n"); errors++; }
    else printf("  PASS\n");

    printf("VSYNC width:     %d lines  (expected 2)\n", vsync_width);
    if (vsync_width != 2) { printf("  FAIL\n"); errors++; }
    else printf("  PASS\n");

    printf("Blanking violations: %d (expected 0)\n", blanking_violations);
    if (blanking_violations != 0) { printf("  FAIL\n"); errors++; }
    else printf("  PASS\n");

    printf("Non-black visible pixels: %ld (expected > 0)\n", total_nonblack);
    if (total_nonblack == 0) { printf("  FAIL\n"); errors++; }
    else printf("  PASS\n");

    printf("\n");
    if (errors == 0)
        printf("RESULT: ALL CHECKS PASSED\n");
    else
        printf("RESULT: %d CHECK(S) FAILED\n", errors);

    trace->close();
    delete trace;
    delete dut;

    return errors ? 1 : 0;
}
