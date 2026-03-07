# LibreSprite Workflow for TT08 VGA Demoscene

This guide covers the LibreSprite-specific workflow for creating pixel art assets. For general content creation strategy, palette theory, and the ffmpeg pipeline, see [content-creation.md](content-creation.md) and [ffmpeg.md](ffmpeg.md).

## Installing LibreSprite

### Flatpak (recommended on Linux)

```bash
flatpak install flathub com.github.AseproteTeam.LibreSprite
flatpak run com.github.AseproteTeam.LibreSprite
```

### From source

```bash
git clone --recursive https://github.com/LibreSprite/LibreSprite.git
cd LibreSprite && mkdir build && cd build
cmake .. && make -j$(nproc)
```

### Nix

```bash
nix-shell -p libresprite
```

## Canvas Setup

### New file settings

**File > New** with these settings:

| Preset   | Width | Height | Scale to 640x480 | Use case |
|---------:|------:|-------:|:-----------------:|----------|
| Standard | 160   | 120    | 4x                | Chunky GWBW aesthetic (recommended) |
| Detail   | 320   | 240    | 2x                | Finer detail when needed |

- **Color Mode**: RGB Color
- **Background**: Black (matches VGA blanking)

### View settings

- **View > Grid > Grid Settings**: 1x1 pixel grid
- **View > Show Grid**: toggle on for precise placement
- Zoom to 400-800% for comfortable editing at 160x120

## Loading the RGB222 Palette

The project ships a ready-to-use palette file at `assets/palettes/rgb222.gpl` containing all 64 RGB222 colors.

### Quick load

1. Open LibreSprite
2. **Palette > Load Palette**
3. Navigate to `assets/palettes/rgb222.gpl`
4. All 64 colors appear in the palette panel

### Permanent install

Copy the palette to LibreSprite's palette directory so it appears in the preset list:

```bash
# Linux (LibreSprite from source)
cp assets/palettes/rgb222.gpl ~/.config/libresprite/palettes/

# Flatpak
cp assets/palettes/rgb222.gpl ~/.var/app/com.github.AseproteTeam.LibreSprite/config/libresprite/palettes/
```

After copying, restart LibreSprite. The palette appears under **Palette > Load Palette** without needing to browse.

## Creating Scene Sub-Palettes

The full 64-color palette is available, but cohesive scenes use a **curated subset of 8-16 colors**. To create a scene-specific sub-palette:

1. Load the full `rgb222.gpl` palette
2. Create your scene, using only colors that fit the mood
3. When done, select **Palette > New Palette from Sprite** to extract only the used colors
4. Save as `assets/palettes/<scene_name>.gpl` via **Palette > Save Palette**

Guidelines for sub-palette selection (from [content-creation.md](content-creation.md)):

- 2-3 dark tones for shadows and backgrounds
- 3-4 mid-tones for primary surfaces
- 1-2 highlights
- 1-2 accent colors (skin, fire, indicators)

## Sprite Sheet Conventions

### File naming

| Type | Source file | Exported PNG |
|------|------------|--------------|
| Single sprite | `player_16x16.ase` | `player_16x16.png` |
| Animated sprite | `fire_8x8.ase` | `fire_8x8.png` (sprite sheet) |
| Scene | `desert_160x120.ase` | `desert_160x120.png` |
| Tileset | `dungeon_tiles_8x8.ase` | `dungeon_tiles_8x8.png` |

Pattern: `<name>_<WxH>.ase` where WxH is the **individual frame/tile size**, not the total sheet size.

### Sprite sizing

Keep sprites at sizes that divide evenly into the canvas:

- **8x8**: small tiles, UI elements, particles
- **16x16**: characters, objects
- **32x32**: large characters, detailed objects
- **160x120** or **320x240**: full scenes/backgrounds

### Sprite sheet layout

When exporting animated sprites:

- **File > Export Sprite Sheet**
- Layout: **Horizontal Strip** (frames left to right)
- This simplifies frame indexing in the hardware pipeline

## Animation Tips

For the GWBW aesthetic, animation should be minimal and deliberate:

- **Idle loops**: 2-4 frames for breathing, flickering, wind
- **Actions**: 8-16 frames, then hold on final pose
- **Backgrounds**: mostly static with one animated element

LibreSprite-specific workflow:

- **Onion skinning** (View > Onion Skinning): see previous/next frames while drawing
- **Frame duration**: right-click a frame in the timeline to set hold time (e.g., 500ms for held poses)
- **Linked cels**: right-click a cel > Link — reuses the same image data, saves memory
- **Tags**: mark frame ranges as loops (idle, walk, action) for organized export

## Export Settings

### For the ffmpeg pipeline

Export frames as PNG for processing with the ffmpeg pipeline documented in [ffmpeg.md](ffmpeg.md):

1. **File > Export** (or Ctrl+Shift+E)
2. Filename: `frames/<name>_{frame01}.png`
3. This exports each frame as a numbered PNG

Then scale and pack with ffmpeg:

```bash
ffmpeg -framerate 10 -i frames/<name>_%02d.png \
  -vf "scale=640:480:flags=neighbor" \
  -r 60 scaled/frame_%04d.png
```

### Sprite sheet export

For sprite sheets (used by a hardware sprite engine):

1. **File > Export Sprite Sheet**
2. Layout: Horizontal Strip
3. Output: PNG
4. Save to `assets/sprites/<name>_<WxH>.png`

### Direct PNG export

For static scenes or single frames, just **File > Save As** and choose PNG format.

## Directory Structure

```
assets/
├── palettes/
│   ├── rgb222.gpl              # Full 64-color RGB222 palette
│   └── <scene_name>.gpl        # Per-scene curated sub-palettes
├── sprites/
│   ├── <name>_<WxH>.ase        # Source files (LibreSprite native)
│   └── <name>_<WxH>.png        # Exported sprite sheets
├── scenes/
│   ├── <name>_<WxH>.ase        # Source scene files
│   └── <name>_<WxH>.png        # Exported scene frames
└── tilesets/
    ├── <name>_<WxH>.ase        # Source tileset files
    └── <name>_<WxH>.png        # Exported tileset sheets
```

Keep `.ase` source files in the repo — they preserve layers, frames, and tags that PNG exports lose.
