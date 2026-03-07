# Content Creation Guide for TT08 VGA Demoscene

## Overview

Target aesthetic: **Gods Will Be Watching** — cinematic pixel art with muted palettes, chunky pixels, and minimal/subtle animation. Think moody lighting, restrained color use, and deliberate stillness broken by small movements.

### Hardware constraints

- **Display**: 640x480 @ 60Hz VGA
- **Color depth**: RGB222 — 2 bits per channel, **64 colors total**
- **Storage**: 16 MB QSPI Flash (under 1 second uncompressed at full resolution)

### Resolution strategy

Author content at **low resolution** and scale up with nearest-neighbor interpolation:

| Author at | Scale factor | Pixel size on screen |
|----------:|:------------:|:--------------------:|
| 160x120   | 4x           | 4x4 pixels          |
| 320x240   | 2x           | 2x2 pixels          |

**160x120** is recommended for the GWBW aesthetic — it gives chunky, expressive pixels and reduces storage by 16x compared to full resolution. Use 320x240 when you need finer detail.

## Palette Setup

### Generating the full RGB222 palette

Each channel has 4 levels. In 8-bit terms: 0, 85, 170, 255 (evenly spread across the full range).

Generate a palette image with Python:

```python
from PIL import Image

img = Image.new("RGB", (64, 1))
i = 0
for r in range(4):
    for g in range(4):
        for b in range(4):
            img.putpixel((i, 0), (r * 85, g * 85, b * 85))
            i += 1
img.save("rgb222_palette.png")
```

Or generate a GIMP/Aseprite `.gpl` palette file:

```python
with open("rgb222.gpl", "w") as f:
    f.write("GIMP Palette\nName: RGB222\nColumns: 8\n#\n")
    for r in range(4):
        for g in range(4):
            for b in range(4):
                f.write(f"{r*85:3d} {g*85:3d} {b*85:3d}  R{r}G{g}B{b}\n")
```

### Working with a curated subset

64 colors is already tight. For cohesive scenes in the GWBW style, pick a **subset of 8-16 colors** per scene:

- 2-3 dark tones for shadows and backgrounds
- 3-4 mid-tones for primary surfaces
- 1-2 highlights
- 1-2 accent colors (skin, fire, indicators)

Example muted desert palette (subset of RGB222):

| Swatch | RGB | Hex | Use |
|--------|-----|-----|-----|
| Dark brown  | (85, 85, 0)   | `#555500` | Deep shadow  |
| Warm gray   | (85, 85, 85)  | `#555555` | Rocks, ground |
| Sand        | (170, 170, 85)| `#AAAA55` | Desert floor  |
| Pale sky    | (85, 170, 170)| `#55AAAA` | Sky           |
| Skin        | (170, 170, 85)| `#AAAA55` | Characters    |
| Highlight   | (255, 255, 170)| `#FFFFAA`| Light sources |
| Dark sky    | (0, 0, 85)    | `#000055` | Night sky     |
| Black       | (0, 0, 0)     | `#000000` | Outlines      |

## Approach 1: Manual Pixel Art (Aseprite / LibreSprite)

### Canvas setup

1. **File > New**: set width/height to 160x120 (or 320x240)
2. **Color Mode**: RGB Color
3. Under **View > Grid > Grid Settings**, set grid to 1x1 pixel

### Importing the RGB222 palette

1. Generate `rgb222.gpl` using the script above
2. In Aseprite: **Palette > Load Palette** and select the `.gpl` file
3. Lock the palette — this prevents Aseprite from auto-adjusting colors

Alternatively, copy the `.gpl` file to Aseprite's palette directory:
- Linux: `~/.config/aseprite/palettes/`
- macOS: `~/Library/Application Support/Aseprite/palettes/`

### Animation workflow

For the GWBW aesthetic, animation should be **minimal and deliberate**:

- **Idle loops**: 2-4 frame cycles for subtle breathing, flickering lights, wind
- **Cinematic moments**: 8-16 frames for key actions, then hold on a pose
- **Background layers**: largely static, with one animated element (smoke, stars, rain)

Aseprite tips:

- **Onion skinning** (View > Onion Skinning): essential for smooth loops
- **Frame duration**: set individual frame timing for held poses (e.g., hold the last frame of a gesture for 500ms)
- **Linked cels**: reuse identical frames across the timeline to save effort and storage
- **Tags**: mark loops (idle, action, transition) for organized export

### Exporting

Export as a **frame sequence** for the ffmpeg pipeline:

- **File > Export Sprite Sheet** — choose "Horizontal Strip" or "By Rows"
- Or **File > Export** — save as `frame_{frame}.png` with frame numbering

For individual frames:
```
File > Export > frames/frame_{frame01}.png
```

### Style tips for the GWBW look

- **Cinematic framing**: use black bars (leave top/bottom rows black for a widescreen feel within the 4:3 frame)
- **Atmospheric lighting**: use darker palette entries for most of the scene; reserve highlights for focal points
- **Limited animation**: a scene with only a campfire flickering and a character breathing is more evocative than full motion
- **Silhouettes**: characters as dark shapes against a slightly lighter background
- **Dithering by hand**: use checkerboard patterns between two palette colors for perceived gradients

## Approach 2: AI-Assisted Generation

Use AI image generation to produce source frames, then post-process to fit RGB222 constraints.

### Tool chain

- **Stable Diffusion** (SD 1.5 or SDXL) / **Flux** with pixel-art LoRAs
- **ComfyUI** or **Automatic1111** as the interface
- Post-processing with ffmpeg and optionally manual cleanup in Aseprite

### Recommended LoRAs and models

Search CivitAI for:
- "pixel art" LoRAs (for SD 1.5: Pixel Art XL, Pixel Art Style)
- "low resolution" or "retro game" style LoRAs
- Models fine-tuned on pixel art (e.g., PixelModel)

### Prompting for the GWBW aesthetic

```
pixel art, low resolution, 160x120, limited color palette,
cinematic scene, muted colors, atmospheric lighting,
dark moody scene, [your scene description],
gods will be watching style, retro game screenshot,
minimal detail, chunky pixels
```

Negative prompt:
```
high resolution, photorealistic, smooth gradients,
anti-aliasing, too many colors, modern 3d,
blurry, watermark, text
```

### Consistency across frames

- **img2img**: use a keyframe as the starting image with 0.3-0.5 denoising strength for variations that maintain composition
- **ControlNet**: use canny edge or depth maps from a reference frame to keep structure consistent across a scene sequence
- **Seed locking**: fix the seed and vary only the prompt slightly for scene variations

### Post-processing pipeline

AI output will not be palette-perfect. Clean it up:

1. **Downscale** to target resolution (if generated at higher res):
   ```bash
   ffmpeg -i ai_output.png -vf "scale=160:120:flags=lanczos" downscaled.png
   ```

2. **Quantize** to RGB222:
   ```bash
   ffmpeg -i downscaled.png -vf "lutrgb=r='bitand(val,192)/192*255':g='bitand(val,192)/192*255':b='bitand(val,192)/192*255'" quantized.png
   ```

3. **Manual cleanup** in Aseprite: fix stray pixels, clean edges, adjust colors to your curated subset

### Frame interpolation warning

AI frame interpolation (RIFE, FILM, etc.) **destroys pixel art crispness**. These tools introduce sub-pixel blending and anti-aliasing. If you need intermediate frames:

- Generate them with img2img from keyframes instead
- Or animate manually between AI-generated keyframes
- Never interpolate after quantization

## Approach 3: Rotoscoping from Video

Convert real video footage into pixel art frames.

### Source footage selection

Best results with:
- **High contrast** scenes (silhouettes, strong lighting)
- **Slow, deliberate movement** (matches the GWBW aesthetic)
- **Simple compositions** (1-2 subjects, clean backgrounds)
- **Static camera** or slow pans

### Basic rotoscope pipeline

```bash
# Downscale, posterize, and quantize in one pass
ffmpeg -i source_video.mp4 -vf "
  scale=160:120:flags=lanczos,
  eq=contrast=1.5:brightness=0.05,
  lutrgb=r='bitand(val,192)/192*255':g='bitand(val,192)/192*255':b='bitand(val,192)/192*255'
" -r 10 frames/frame_%04d.png
```

### Enhanced pipeline with edge detection

For a more stylized look, combine edge detection with color reduction:

```bash
# Stylized rotoscope with edge overlay
ffmpeg -i source_video.mp4 -filter_complex "
  [0:v]scale=160:120:flags=lanczos[scaled];

  [scaled]split[a][b];

  [a]edgedetect=low=0.1:high=0.3:mode=colormix,
     negate[edges];

  [b]eq=contrast=1.8:brightness=-0.1,
     hue=s=0.5,
     lutrgb=r='bitand(val,192)/192*255':g='bitand(val,192)/192*255':b='bitand(val,192)/192*255'[colors];

  [colors][edges]blend=all_mode=multiply[out]
" -map "[out]" -r 10 frames/frame_%04d.png
```

Key filters:
- `edgedetect` — extracts outlines (adjust `low`/`high` thresholds to taste)
- `eq=contrast=1.8` — push contrast to reduce muddy mid-tones
- `hue=s=0.5` — desaturate for the muted GWBW look
- `colorlevels` — fine-tune per-channel brightness/contrast for color grading

### Posterize for fewer tones

For a more graphic look, posterize before quantizing:

```bash
ffmpeg -i source_video.mp4 -vf "
  scale=160:120:flags=lanczos,
  colorlevels=rimin=0.1:rimax=0.9:gimin=0.1:gimax=0.9:bimin=0.1:bimax=0.9,
  eq=contrast=2.0:brightness=-0.05,
  hue=s=0.3,
  lutrgb=r='bitand(val,192)/192*255':g='bitand(val,192)/192*255':b='bitand(val,192)/192*255'
" -r 10 frames/frame_%04d.png
```

### Semi-automated workflow

The best results come from combining automated conversion with hand touch-up:

1. Run the ffmpeg pipeline above to generate base frames
2. Import the frame sequence into Aseprite
3. Load the RGB222 palette
4. Clean up key frames: fix outlines, remove noise, adjust colors
5. Use Aseprite's onion skinning to ensure frame-to-frame consistency
6. Export the cleaned sequence

## Approach 4: Procedural / On-Chip

Some demoscene effects are best generated in hardware rather than pre-rendered.

### When to use procedural

- **Palette cycling**: color rotation through the 64-color palette creates flowing/animated effects with zero frame storage
- **XOR patterns**: classic demoscene textures generated from pixel coordinates
- **Plasma effects**: sine-table-based color fields
- **Simple sprite engines**: small sprites composited over procedural backgrounds
- **Starfields**: random dots with parallax scrolling

### When to use pre-rendered

- **Narrative scenes** with specific compositions
- **Character animation** requiring hand-crafted detail
- **Rotoscoped footage** from real video
- **Complex scenes** that would be impractical to generate in real-time on TT08

### Hybrid approach

Combine both: use procedural backgrounds (starfield, gradient sky, palette cycling) with pre-rendered sprite overlays stored in flash. This stretches storage much further.

Procedural generation is covered in detail in the hardware design docs.

## Scaling to 640x480

All content authored at low resolution must be scaled up for VGA output. Use **nearest-neighbor** interpolation to preserve pixel art crispness.

### With ffmpeg

From individual frames:
```bash
ffmpeg -i frames/frame_%04d.png -vf "scale=640:480:flags=neighbor" -r 60 scaled/frame_%04d.png
```

From a low-res video:
```bash
ffmpeg -i lowres.mp4 -vf "scale=640:480:flags=neighbor" -r 60 -c:v libx264 -pix_fmt yuv420p scaled.mp4
```

The `flags=neighbor` parameter is critical — without it, ffmpeg defaults to bicubic scaling which blurs pixel edges and introduces colors outside the RGB222 palette.

### Aspect ratio considerations

| Source | Target | Result |
|--------|--------|--------|
| 160x120 (4:3) | 640x480 (4:3) | Perfect 4x fit, no padding needed |
| 320x240 (4:3) | 640x480 (4:3) | Perfect 2x fit, no padding needed |
| 160x90 (16:9) | 640x480 (4:3) | Scale to 640x360, 60px black bars top/bottom |

For cinematic widescreen within the 4:3 frame, author at **160x90** and let the black bars provide the letterboxing naturally.

## Integration with ffmpeg.md

After creating your content at low resolution, the full pipeline is:

1. **Author** at 160x120 (this doc)
2. **Scale up** to 640x480 with `flags=neighbor` (above)
3. **Quantize** to RGB222 if not already palette-locked (see [ffmpeg.md](ffmpeg.md))
4. **Export** as raw frames or packed RGB222 bytes (see [ffmpeg.md](ffmpeg.md))
5. **Compress** with RLE or delta encoding for flash storage

### Combined one-liner: low-res frames to packed RGB222

```bash
ffmpeg -framerate 10 -i frames/frame_%04d.png -vf "
  scale=640:480:flags=neighbor,
  lutrgb=r='bitand(val,192)/192*255':g='bitand(val,192)/192*255':b='bitand(val,192)/192*255'
" -r 60 -f rawvideo -pix_fmt rgb24 - | \
python3 -c "
import sys
data = sys.stdin.buffer.read()
out = bytearray()
for i in range(0, len(data), 3):
    r, g, b = data[i], data[i+1], data[i+2]
    packed = (r & 0xC0) | ((g & 0xC0) >> 2) | ((b & 0xC0) >> 4)
    out.append(packed)
sys.stdout.buffer.write(out)
" > output_packed.raw
```

See [ffmpeg.md](ffmpeg.md) for detailed documentation on quantization methods, dithering options, raw export formats, and storage considerations.
