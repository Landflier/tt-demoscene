# GIF to RGB222 Sprite Sheet with ImageMagick

## Goal

Convert an animated GIF into a sprite sheet with colors remapped to the RGB222 palette (64 colors, 2 bits per channel). This is useful for preparing animation assets for the Tiny Tapeout VGA output.

## Prerequisites

- ImageMagick (`convert`, `montage`)
- An animated GIF (e.g., `assets/balrog-gandalf.gif` — 498x210, 86 frames, 256 colors)
- The RGB222 palette file (`assets/palettes/rgb222.gpl`)

## Step 1: Generate a Palette PNG from `rgb222.gpl`

ImageMagick's `-remap` requires a palette image. Generate a 64x1 PNG where each pixel is one of the 64 RGB222 colors:

```bash
# Parse the .gpl file and build a 64x1 palette PNG
convert -size 1x1 xc:black \
  $(grep -E '^\s*[0-9]' assets/palettes/rgb222.gpl | \
    awk '{printf "-fill \"rgb(%s,%s,%s)\" -draw \"point %d,0\" ", $1, $2, $3, NR-1}') \
  -extent 64x1 rgb222_palette.png
```

A more reliable approach is to use a script (see `scripts/gif_to_spritesheet.sh`) that reads each RGB triplet from the `.gpl` file and builds the palette image pixel by pixel.

## Step 2: Extract GIF Frames

Use `-coalesce` to properly composite all frames. GIFs use delta encoding and disposal methods, so without `-coalesce` you get partial or broken frames:

```bash
mkdir -p frames
convert assets/balrog-gandalf.gif -coalesce frames/frame_%04d.png
```

This produces `frame_0000.png` through `frame_0085.png` (86 frames).

## Step 3: Remap Colors to RGB222

Use `-remap` with the palette PNG and `-dither None` to force nearest-color mapping (Euclidean distance in RGB space) with no dithering:

```bash
mkdir -p remapped
for f in frames/frame_*.png; do
  convert "$f" -remap rgb222_palette.png +dither remapped/$(basename "$f")
done
```

- `+dither` (or `-dither None`) disables dithering, so each pixel maps to the absolute closest RGB222 color
- This is equivalent to snapping each channel to the nearest value in {0, 85, 170, 255}

## Step 4: Assemble Sprite Sheet

Use `montage` to tile all remapped frames into a single sprite sheet:

```bash
montage remapped/frame_*.png \
  -tile 10x9 \
  -geometry 498x210+0+0 \
  -background none \
  spritesheet.png
```

- `-tile 10x9` — 10 columns, 9 rows (fits 86 frames; last row is partially filled)
- `-geometry 498x210+0+0` — each cell is 498x210 with no padding between frames
- `-background none` — transparent background for unfilled cells

The output sprite sheet will be 4980x1890 pixels (10 x 498 wide, 9 x 210 tall).

## Verification

Check that the output has at most 64 colors:

```bash
identify -verbose spritesheet.png | grep "Colors:"
```

Inspect frame count and dimensions:

```bash
identify spritesheet.png
```

## Automated Script

See `scripts/gif_to_spritesheet.sh` for a script that runs the full pipeline:

```bash
./scripts/gif_to_spritesheet.sh \
  assets/balrog-gandalf.gif \
  assets/palettes/rgb222.gpl \
  assets/sprites/balrog-gandalf-spritesheet.png
```
