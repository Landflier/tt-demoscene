# VGA Interface Reference for Tiny Tapeout

## Overview

The **Tiny VGA PMOD** is a small add-on board that connects to a Tiny Tapeout chip's 8-bit output port (`uo_out[7:0]`) and produces a VGA-compatible analog video signal. It uses an R-2R resistor DAC to convert 2-bit-per-channel digital color data into analog RGB levels, providing 64 possible colors (RGB222).

The PMOD plugs directly into the output header of the Tiny Tapeout demo board. No additional circuitry is needed between the TT chip and a VGA monitor.

## Pin Mapping

The Tiny VGA PMOD uses a **non-contiguous** pin mapping on `uo_out[7:0]`. This is dictated by the PMOD connector layout and the R-2R DAC wiring on the board.

| `uo_out` bit | Signal | Description       |
|:------------:|--------|-------------------|
| `[0]`        | R1     | Red MSB           |
| `[1]`        | G1     | Green MSB         |
| `[2]`        | B1     | Blue MSB          |
| `[3]`        | VSYNC  | Vertical sync     |
| `[4]`        | R0     | Red LSB           |
| `[5]`        | G0     | Green LSB         |
| `[6]`        | B0     | Blue LSB          |
| `[7]`        | HSYNC  | Horizontal sync   |

In Verilog, the output assignment typically looks like:

```verilog
assign uo_out = {hsync, b0, g0, r0, vsync, b1, g1, r1};
//                [7]  [6] [5] [4]   [3]  [2] [1] [0]
```

To reconstruct full 2-bit color channels from these non-contiguous bits:

```verilog
wire [1:0] red   = {uo_out[4], uo_out[0]};  // {R0, R1} → but R1 is MSB
wire [1:0] green = {uo_out[5], uo_out[1]};
wire [1:0] blue  = {uo_out[6], uo_out[2]};
```

More precisely: `R[1:0] = {R1, R0} = {uo_out[0], uo_out[4]}` — bit 0 is the MSB.

## Color Encoding

The Tiny VGA PMOD uses **RGB222** encoding — 2 bits per color channel, 6 bits total, producing **64 colors**.

The R-2R resistor ladder DAC on the PMOD board converts each 2-bit digital value to an analog voltage:

| Bits `[1:0]` | Analog level |
|:------------:|:------------:|
| `00`         | 0.00 V       |
| `01`         | 0.23 V       |
| `10`         | 0.46 V       |
| `11`         | 0.70 V       |

VGA specifies 0.0–0.7 V for each color channel, so the full 2-bit range covers the entire analog output range.

## VGA Timing (640x480 @ 60 Hz)

### Horizontal Timing

| Parameter     | Pixels | Time (us) |
|---------------|-------:|----------:|
| Visible area  |    640 |    25.422 |
| Front porch   |     16 |     0.636 |
| Sync pulse    |     96 |     3.813 |
| Back porch    |     48 |     1.907 |
| **Total line**|  **800**| **31.778**|

HSYNC polarity: **negative** (active low during sync pulse).

### Vertical Timing

| Parameter     |  Lines | Time (ms) |
|---------------|-------:|----------:|
| Visible area  |    480 |    15.253 |
| Front porch   |     10 |     0.318 |
| Sync pulse    |      2 |     0.064 |
| Back porch    |     33 |     1.049 |
| **Total frame**| **525**| **16.683**|

VSYNC polarity: **negative** (active low during sync pulse).

Frame rate: 800 x 525 = 420,000 pixels/frame at 25.175 MHz = ~59.94 Hz.

## Clock Requirements

The standard 640x480@60Hz VGA mode requires a **25.175 MHz** pixel clock. In practice, 25.0 MHz works with nearly all monitors.

Tiny Tapeout provides a configurable clock input (`clk`). For TT08 and later shuttles, the clock can be set via the demo board's RP2040 microcontroller. Common approaches:

- **Direct 25 MHz clock** from the demo board (simplest)
- **Higher clock with divider** — e.g., 50 MHz input, divide by 2 internally
- **PLL on demo board** — the RP2040 can generate precise frequencies

The design's top module receives `clk` and must generate all VGA timing from it.

## Signal Generation

A typical VGA controller uses two free-running counters:

```
h_counter: 0 → 799 (resets each line)
v_counter: 0 → 524 (increments when h_counter resets, resets each frame)
```

From these counters, derive:

```verilog
// Sync signals (active low)
assign hsync = ~(h_counter >= 656 && h_counter < 752);  // 640+16 to 640+16+96
assign vsync = ~(v_counter >= 490 && v_counter < 492);  // 480+10 to 480+10+2

// Blanking (active area only)
assign visible = (h_counter < 640) && (v_counter < 480);

// Pixel coordinates within visible area
assign pixel_x = h_counter;  // 0–639
assign pixel_y = v_counter;  // 0–479
```

During blanking intervals (when `visible` is low), RGB outputs **must be driven to zero**. Outputting color data during blanking will corrupt the image on most monitors.

## Racing the Beam

Tiny Tapeout tiles provide roughly **1000 standard cells** (~1000 gates). This is far too little for a framebuffer — even a 1-bit 640x480 framebuffer would require 38,400 bytes of RAM.

Instead, TT VGA designs must **compute each pixel on-the-fly** as the beam scans across the screen, a technique known as "racing the beam" (after the Atari 2600's similar constraint).

Practical approaches:

- **Procedural patterns** — plasma, XOR patterns, color cycling. Generated purely from `(x, y, frame_counter)` with combinational logic.
- **Lookup tables in external Flash** — store pre-computed frames, palettes, or sin/cos tables on the QSPI Flash PMOD and stream data in sync with the beam.
- **RLE-compressed video** — store run-length encoded frames in Flash, decompress in real-time.
- **Simple geometry** — render lines, rectangles, or wireframes using comparators and counters.

The key constraint: you must produce the correct pixel color **every clock cycle** during the visible area. There is no time to "think" — the pixel must be ready when the beam arrives.

## GPIO Summary

| Port           | Width | Direction | Usage in this project          |
|----------------|:-----:|:---------:|-------------------------------|
| `ui_in[7:0]`   |   8   |   Input   | User inputs (buttons, switches)|
| `uo_out[7:0]`  |   8   |   Output  | VGA signals (Tiny VGA PMOD)    |
| `uio[7:0]`     |   8   |   Bidir   | QSPI PMOD (Flash + PSRAM)     |

Additional signals available to the top module:

| Signal   | Description                        |
|----------|------------------------------------|
| `clk`    | System clock                       |
| `rst_n`  | Active-low reset                   |
| `ena`    | Active-high enable (active when design is selected) |

## Reference Projects

These TT08 demoscene entries demonstrate VGA output techniques:

- **tt08-vga-drop** (rejunity) — VGA raindrop effect
  https://github.com/rejunity/tt08-vga-drop

- **tt08-vga-donut** (a1k0n) — Spinning 3D donut rendered in real-time
  https://github.com/a1k0n/tt08-vga-donut

- **vga-playground hvsync_generator** — Minimal VGA timing reference
  https://github.com/amundsen/vga-playground

- **a1k0n's blog post** — Detailed writeup on fitting a donut renderer in ~1000 gates
  https://a1k0n.net/2024/08/19/tinytt-donut.html

- **tt08-wirecube** (mole99) — Wireframe cube on VGA
  https://github.com/mole99/tt08-wirecube

## References

- Tiny Tapeout documentation: https://tinytapeout.com
- Tiny VGA PMOD (mole99): https://github.com/mole99/tiny-vga
- TT VGA output guide: https://tinytapeout.com/specs/gpio/#active-low-active-high
- tinyvga.com VGA timing: http://www.tinyvga.com/vga-timing/640x480@60Hz
- Video timings calculator: https://tomverbeure.github.io/video_timings_calculator
- TT08 demoscene competition entries: https://tinytapeout.com/competitions/demoscene-tt08-entries/
