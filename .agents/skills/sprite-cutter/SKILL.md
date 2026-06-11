---
name: sprite-cutter
description: >-
  Split a sprite sheet or icon grid image into individual sub-images.
  Use when the user asks to crop, cut, split, or slice a grid of icons,
  tiles, or sprites from a single image into separate files.
---

# Sprite Cutter

将网格排列的精灵图/图标合集切割为独立的子图片。

## Usage

Run the script:

```bash
python .cursor/skills/sprite-cutter/scripts/split_sprites.py <input_image> [options]
```

### Options

| Flag | Default | Description |
|------|---------|-------------|
| `--cols` | auto | 列数 |
| `--rows` | auto | 行数 |
| `--output` | `<input_dir>/<input_stem>_sprites/` | 输出目录 |
| `--prefix` | `sprite` | 输出文件名前缀 |
| `--format` | `png` | 输出格式 (png/jpg/webp) |
| `--padding` | auto | 图标间距（像素），auto 时自动检测 |
| `--margin` | auto | 图片边缘留白（像素），auto 时自动检测 |
| `--trim` | flag | 裁剪每个子图的多余透明/白色边缘 |
| `--names` | none | 逗号分隔的名称列表，按从左到右、从上到下顺序命名 |

### Examples

Auto-detect grid and split:

```bash
python .cursor/skills/sprite-cutter/scripts/split_sprites.py assets/generated/wukong-skill.png
```

Specify grid size and custom names:

```bash
python .cursor/skills/sprite-cutter/scripts/split_sprites.py assets/generated/wukong-skill.png \
  --cols 4 --rows 3 \
  --names "stone_birth,star_eyes,golden_embryo,waterfall_cave,seasons,monkey_king,mentor,dragon,somersault,heavenly_stable,midnight_study,stone_shatter" \
  --output assets/skills/wukong/
```

Trim whitespace from each icon:

```bash
python .cursor/skills/sprite-cutter/scripts/split_sprites.py assets/generated/wukong-skill.png --trim
```

## Workflow

1. Determine the input image path and desired output
2. Run the split script with appropriate options
3. Verify the output directory contains the expected number of sub-images
4. If auto-detection fails, manually specify `--cols` and `--rows`

## Requirements

- Python 3.8+
- Pillow (`pip install Pillow`)
