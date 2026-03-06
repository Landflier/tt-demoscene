# TinyTapeout TTSKY26a VGA Demoscene Project Plan

## Target
- **Shuttle**: TTSKY26a (Sky130 PDK via ChipFoundry)
- **Closes**: May 2026
- **Tile size**: ~160x100 um (~1000 gates)

## Project Goals
Create a VGA demoscene project rendering video output, similar to TT08 demoscene entries.

## Hardware
- **VGA Pmod** on `uo_out[7:0]` - Video output
- **QSPI Pmod** on `uio[7:0]` - External Flash (16MB) + PSRAM (16MB) for demo assets

---

## Execution Plan

### Phase 1: Environment Setup
1. Enter dev shell: `nix develop`
2. Install Sky130 PDK using ciel:
   ```
   ciel enable --pdk-family sky130 <commit-hash>
   ```
3. Set `PDK_ROOT` environment variable

### Phase 2: VGA Skeleton
1. Create `src/` directory with:
   - `tt_um_vga_demo.v` - Top module following TinyTapeout pinout
   - `vga_timing.v` - VGA signal generator (640x480 @ 60Hz or 25.175MHz)
   - `pixel_generator.v` - Demo effect renderer

2. TinyTapeout pinout:
   - `uo_out[7:0]` - VGA signals: R[1:0], G[1:0], B[1:0], hsync, vsync
   - `ui_in[7:0]` - Optional inputs
   - `uio[7:0]` - QSPI Pmod (directly active I/O):
     - `uio[0]` CS0 (Flash)
     - `uio[1]` SD0/MOSI
     - `uio[2]` SD1/MISO
     - `uio[3]` SCK
     - `uio[4]` SD2
     - `uio[5]` SD3
     - `uio[6]` CS1 (RAM A)
     - `uio[7]` CS2 (RAM B)

3. VGA timing (640x480 @ 60Hz):
   - Pixel clock: 25.175 MHz
   - H: 640 visible, 16 front porch, 96 sync, 48 back porch
   - V: 480 visible, 10 front porch, 2 sync, 33 back porch

### Phase 3: QSPI Controller
1. Create `src/qspi_controller.v` - QSPI interface for Flash/PSRAM
2. Implement:
   - SPI mode for initial setup
   - QSPI mode for fast reads (4-bit parallel)
   - Flash read commands (e.g., 0x6B for quad read)
   - PSRAM access for framebuffer or lookup tables
3. Use Flash for:
   - Pre-rendered frames / sprites
   - Lookup tables (sin/cos, palette)
   - RLE-encoded video data
4. Use PSRAM for:
   - Runtime framebuffer
   - Working memory for effects
5. Flash the Pmod using TinyTapeout Flasher app

### Phase 4: Demo Effect Ideas
Choose one or combine:
- Plasma effect (sin/cos lookup tables)
- Scrolling patterns
- Simple raymarching
- Wireframe shapes
- Color cycling

### Phase 5: Testbench
1. Create `test/tb.v` - Cocotb or Verilator testbench
2. Generate VGA frame dumps for verification
3. Use GTKWave for waveform inspection

### Phase 6: VGA Video CI Workflow
Set up automatic VGA output rendering on every push using Uri Shaked's vga-sim tool.

1. Create `vga-sim/` directory with:
   - `vga_sim.py` - From https://github.com/urish/tt-2048-game/tree/main/vga-sim
   - `requirements.txt` - Python dependencies (Pillow, etc.)
   - `events.yaml` - Optional input events (frame:value pairs)

2. Create `.github/workflows/vga-video.yaml`:
   ```yaml
   name: vga-video
   on:
     push:
     workflow_dispatch:
   jobs:
     render:
       runs-on: ubuntu-24.04
       steps:
         - uses: actions/checkout@v4
         - name: Install dependencies
           run: |
             sudo apt-get update
             sudo apt-get install -y verilator ffmpeg
             pip install -r vga-sim/requirements.txt
         - name: Render VGA video
           run: |
             python3 vga-sim/vga_sim.py . -n 120 \
               -d vga_frames -o frame \
               --video vga_output.mp4
         - uses: actions/upload-artifact@v4
           with:
             name: vga-video
             path: |
               vga_frames/vga_output.mp4
               vga_frames/frame_*.png
   ```

3. The simulator:
   - Reads `info.yaml` for source files and top module
   - Compiles with Verilator
   - Runs simulation capturing VGA output
   - Generates PNG frames and MP4 video
   - Uploads as GitHub artifact

### Phase 7: Synthesis & Hardening
1. Create `info.yaml` with project metadata
2. Run LibreLane flow for GDS generation
3. Verify timing closure at 25.175 MHz
4. Check gate count fits within tile

### Phase 8: Submission
1. Fork `ttsky-verilog-template` from TinyTapeout
2. Add source files and info.yaml
3. Push to GitHub - CI will run hardening
4. Submit via TinyTapeout app

---

## References
- TinyTapeout: https://tinytapeout.com
- TTSKY template: https://github.com/TinyTapeout/ttsky-verilog-template
- VGA timing: http://www.tinyvga.com/vga-timing
- TT08 demoscene entries: https://tinytapeout.com/competitions/demoscene-tt08-entries/
- Ciel PDK manager: https://github.com/fossi-foundation/ciel
- VGA simulator (Uri Shaked): https://github.com/urish/tt-2048-game/tree/main/vga-sim
- QSPI Pmod (Leo Moser): https://github.com/mole99/qspi-pmod
- TinyTapeout Flasher: https://github.com/TinyTapeout/tinytapeout-flasher
- RLE Video Player example: https://tinytapeout.com/runs/tt07/tt_um_MichaelBell_rle_vga

## TT08 Example Projects for Reference
- tt08-vga-drop (rejunity)
- tt08-wirecube (mole99)
- tt08-sea-battle-vga-game (yuri-panchul)
