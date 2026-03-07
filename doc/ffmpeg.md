# Converting Video for TT08 VGA with FFmpeg

## Goal

Convert an arbitrary video file into frames compatible with the Tiny Tapeout VGA output:

- **Resolution**: 640x480
- **Color depth**: RGB222 (2 bits per channel, 64 colors)
- **Frame rate**: 60 fps (matching VGA 640x480@60Hz)

The output can then be RLE-encoded or otherwise compressed for storage on the QSPI Flash PMOD.

## Resolution and Frame Rate

Scale the input to fit within 640x480, preserving aspect ratio and padding with black:

```bash
ffmpeg -i input.mp4 -vf "scale=640:480:force_original_aspect_ratio=decrease,pad=640:480:(ow-iw)/2:(oh-ih)/2:black" -r 60 output.mp4
```

- `scale=640:480:force_original_aspect_ratio=decrease` — scales down to fit, preserving aspect ratio
- `pad=640:480:...` — centers the result on a 640x480 black canvas
- `-r 60` — resamples to 60 fps

## RGB222 Color Quantization

### Method 1: LUT-based (simple, no dithering)

Use `lutrgb` to quantize each 8-bit channel down to 2-bit precision:

```bash
ffmpeg -i input.mp4 -vf "
  scale=640:480:force_original_aspect_ratio=decrease,
  pad=640:480:(ow-iw)/2:(oh-ih)/2:black,
  lutrgb=r='bitand(val,192)':g='bitand(val,192)':b='bitand(val,192)'
" -r 60 -c:v libx264 -pix_fmt yuv420p output_rgb222.mp4
```

This masks each channel to keep only the top 2 bits (`val & 0xC0`), mapping each channel to one of 4 levels: 0, 64, 128, 192. The result has exactly 64 unique colors.

To map to the full 0-255 range for better preview (spreading the 2-bit values evenly):

```bash
lutrgb=r='bitand(val,192)/192*255':g='bitand(val,192)/192*255':b='bitand(val,192)/192*255'
```

### Method 2: Palette-based (with dithering)

Generate a 64-color palette and apply it with dithering for better visual quality:

```bash
# Step 1: Generate the RGB222 palette (64 colors)
ffmpeg -f lavfi -i "
  color=s=8x8:d=1,
  palettegen=max_colors=64:stats_mode=single
" -frames:v 1 palette_placeholder.png
```

However, for an exact RGB222 palette it's better to generate it programmatically. A simpler two-pass approach using ffmpeg's built-in palette tools:

```bash
# Pass 1: Generate palette from the video (limited to 64 colors)
ffmpeg -i input.mp4 -vf "
  scale=640:480:force_original_aspect_ratio=decrease,
  pad=640:480:(ow-iw)/2:(oh-ih)/2:black,
  palettegen=max_colors=64
" -y palette.png

# Pass 2: Apply palette with Bayer dithering
ffmpeg -i input.mp4 -i palette.png -lavfi "
  [0:v]scale=640:480:force_original_aspect_ratio=decrease,
  pad=640:480:(ow-iw)/2:(oh-ih)/2:black[v];
  [v][1:v]paletteuse=dither=bayer:bayer_scale=3
" -r 60 -c:v libx264 -pix_fmt yuv420p output_dithered.mp4
```

- `dither=bayer` — ordered dithering, produces a regular pattern that looks good on low-color displays
- `bayer_scale=3` — controls dither pattern size (0-5, lower = finer pattern). Try values 2-4.
- Alternative: `dither=floyd_steinberg` for error-diffusion dithering (smoother gradients, but can look noisy)

## Exporting Raw Frames

For hardware playback, you need raw pixel data rather than encoded video.

### Export as individual PNGs

```bash
ffmpeg -i input.mp4 -vf "
  scale=640:480:force_original_aspect_ratio=decrease,
  pad=640:480:(ow-iw)/2:(oh-ih)/2:black,
  lutrgb=r='bitand(val,192)':g='bitand(val,192)':b='bitand(val,192)'
" -r 60 frames/frame_%05d.png
```

### Export as raw RGB bytes

```bash
ffmpeg -i input.mp4 -vf "
  scale=640:480:force_original_aspect_ratio=decrease,
  pad=640:480:(ow-iw)/2:(oh-ih)/2:black,
  lutrgb=r='bitand(val,192)':g='bitand(val,192)':b='bitand(val,192)'
" -r 60 -f rawvideo -pix_fmt rgb24 output.raw
```

Each frame is 640 x 480 x 3 = 921,600 bytes. Pixels are stored left-to-right, top-to-bottom, as R, G, B triplets (each byte has only its top 2 bits set).

### Export as raw RGB222 packed (1 byte per pixel)

To pack each pixel into a single byte as `RRGGBB00` (matching the 2-bit-per-channel layout), post-process the raw output:

```bash
ffmpeg -i input.mp4 -vf "
  scale=640:480:force_original_aspect_ratio=decrease,
  pad=640:480:(ow-iw)/2:(oh-ih)/2:black,
  lutrgb=r='bitand(val,192)':g='bitand(val,192)':b='bitand(val,192)'
" -r 60 -f rawvideo -pix_fmt rgb24 - | \
python3 -c "
import sys
data = sys.stdin.buffer.read()
out = bytearray()
for i in range(0, len(data), 3):
    r, g, b = data[i], data[i+1], data[i+2]
    # Pack as RRGGBB00: top 2 bits of each channel
    packed = (r & 0xC0) | ((g & 0xC0) >> 2) | ((b & 0xC0) >> 4)
    out.append(packed)
sys.stdout.buffer.write(out)
" > output_packed.raw
```

Each frame is now 640 x 480 = 307,200 bytes (1 byte per pixel).

## Complete One-Liner Examples

### Quick preview (quantized, no dithering)

```bash
ffmpeg -i input.mp4 -vf "scale=640:480:force_original_aspect_ratio=decrease,pad=640:480:(ow-iw)/2:(oh-ih)/2:black,lutrgb=r='bitand(val,192)':g='bitand(val,192)':b='bitand(val,192)'" -r 60 -c:v libx264 -pix_fmt yuv420p preview.mp4
```

### With dithering (two-pass)

```bash
ffmpeg -i input.mp4 -vf "scale=640:480:force_original_aspect_ratio=decrease,pad=640:480:(ow-iw)/2:(oh-ih)/2:black,palettegen=max_colors=64" -y /tmp/pal.png && \
ffmpeg -i input.mp4 -i /tmp/pal.png -lavfi "[0:v]scale=640:480:force_original_aspect_ratio=decrease,pad=640:480:(ow-iw)/2:(oh-ih)/2:black[v];[v][1:v]paletteuse=dither=bayer:bayer_scale=3" -r 60 -c:v libx264 -pix_fmt yuv420p preview_dithered.mp4
```

### Export PNG frames for further processing

```bash
mkdir -p frames && ffmpeg -i input.mp4 -vf "scale=640:480:force_original_aspect_ratio=decrease,pad=640:480:(ow-iw)/2:(oh-ih)/2:black,lutrgb=r='bitand(val,192)':g='bitand(val,192)':b='bitand(val,192)'" -r 60 frames/frame_%05d.png
```

## Previewing the Output

Play the quantized video directly with ffplay:

```bash
ffplay -i preview.mp4
```

Or preview the raw stream without saving:

```bash
ffplay -f rawvideo -pixel_format rgb24 -video_size 640x480 -framerate 60 output.raw
```

## Storage Considerations

At 640x480 with RGB222 packed (1 byte/pixel), each frame is ~300 KB. At 60 fps:

| Duration | Uncompressed size |
|---------:|------------------:|
| 1 second |            18 MB  |
| 5 seconds|            90 MB  |
| 10 seconds|          180 MB  |

The QSPI Flash PMOD has 16 MB, so uncompressed video is limited to under 1 second. Compression (e.g., RLE) is essential. Strategies:

- **Reduce frame rate** — 30 fps or 15 fps halves/quarters storage
- **Reduce resolution** — e.g., 320x240 (quarter the pixels), scale up on playback
- **RLE encoding** — compress runs of identical pixels
- **Delta encoding** — store only changed pixels between frames
- **Use PSRAM** — the 16 MB PSRAM can buffer decompressed frames
