#!/usr/bin/env bash
#
# Convert an animated GIF to an RGB222-palette sprite sheet using ImageMagick.
#
# Usage:
#   ./scripts/gif_to_spritesheet.sh <input.gif> <palette.gpl> <output.png> [columns]
#
# Arguments:
#   input.gif    - Animated GIF file
#   palette.gpl  - GIMP palette file (e.g., assets/palettes/rgb222.gpl)
#   output.png   - Output sprite sheet path
#   columns      - Number of columns in the sprite sheet (default: 10)

set -euo pipefail

if [ $# -lt 3 ]; then
    echo "Usage: $0 <input.gif> <palette.gpl> <output.png> [columns]"
    exit 1
fi

INPUT_GIF="$1"
PALETTE_GPL="$2"
OUTPUT_PNG="$3"
COLUMNS="${4:-10}"

# Verify inputs exist
if [ ! -f "$INPUT_GIF" ]; then
    echo "Error: Input GIF not found: $INPUT_GIF"
    exit 1
fi
if [ ! -f "$PALETTE_GPL" ]; then
    echo "Error: Palette file not found: $PALETTE_GPL"
    exit 1
fi

# Create a temporary working directory
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

echo "==> Generating palette PNG from $PALETTE_GPL"

# Parse the .gpl file to extract RGB values and build a palette PNG.
# Each color becomes one pixel in a Nx1 image.
COLORS=()
while IFS= read -r line; do
    # Skip header lines (GIMP Palette, Name:, Columns:, comments)
    if [[ "$line" =~ ^[[:space:]]*([0-9]+)[[:space:]]+([0-9]+)[[:space:]]+([0-9]+) ]]; then
        r="${BASH_REMATCH[1]}"
        g="${BASH_REMATCH[2]}"
        b="${BASH_REMATCH[3]}"
        COLORS+=("rgb($r,$g,$b)")
    fi
done < "$PALETTE_GPL"

NUM_COLORS=${#COLORS[@]}
if [ "$NUM_COLORS" -eq 0 ]; then
    echo "Error: No colors found in palette file"
    exit 1
fi
echo "    Found $NUM_COLORS colors"

PALETTE_PNG="$TMPDIR/palette.png"

# Build the palette image: one pixel per color using a pixel enumeration (txt) format
{
    echo "# ImageMagick pixel enumeration: ${NUM_COLORS},1,255,srgb"
    for i in "${!COLORS[@]}"; do
        # Extract r,g,b from "rgb(r,g,b)"
        color="${COLORS[$i]}"
        color="${color#rgb(}"
        color="${color%)}"
        IFS=',' read -r r g b <<< "$color"
        echo "$i,0: ($r,$g,$b)"
    done
} > "$TMPDIR/palette.txt"
convert "$TMPDIR/palette.txt" "$PALETTE_PNG"

echo "==> Extracting frames from $INPUT_GIF (with -coalesce)"

FRAMES_DIR="$TMPDIR/frames"
mkdir -p "$FRAMES_DIR"
convert "$INPUT_GIF" -coalesce "$FRAMES_DIR/frame_%04d.png"

FRAME_COUNT=$(ls "$FRAMES_DIR"/frame_*.png 2>/dev/null | wc -l)
echo "    Extracted $FRAME_COUNT frames"

if [ "$FRAME_COUNT" -eq 0 ]; then
    echo "Error: No frames extracted"
    exit 1
fi

# Get frame dimensions from the first frame
FRAME_SIZE=$(identify -format "%wx%h" "$FRAMES_DIR/frame_0000.png")
echo "    Frame size: $FRAME_SIZE"

echo "==> Remapping colors to RGB222 palette (+dither = no dithering)"

REMAPPED_DIR="$TMPDIR/remapped"
mkdir -p "$REMAPPED_DIR"
for f in "$FRAMES_DIR"/frame_*.png; do
    convert "$f" -remap "$PALETTE_PNG" +dither "$REMAPPED_DIR/$(basename "$f")"
done

echo "==> Assembling sprite sheet"

# Calculate rows needed
ROWS=$(( (FRAME_COUNT + COLUMNS - 1) / COLUMNS ))
echo "    Layout: ${COLUMNS}x${ROWS} (${FRAME_COUNT} frames)"

# Ensure output directory exists
mkdir -p "$(dirname "$OUTPUT_PNG")"

montage "$REMAPPED_DIR"/frame_*.png \
    -tile "${COLUMNS}x${ROWS}" \
    -geometry "${FRAME_SIZE}+0+0" \
    -background none \
    "$OUTPUT_PNG"

OUTPUT_SIZE=$(identify -format "%wx%h" "$OUTPUT_PNG")
echo "==> Done: $OUTPUT_PNG ($OUTPUT_SIZE)"
