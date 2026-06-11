#!/usr/bin/env python3
"""Split a grid-based sprite sheet into individual sub-images.

Uses OpenCV contour detection for pixel-perfect icon boundary extraction,
with optional alpha masking to make areas outside rounded corners transparent.
"""

import argparse
import sys
from pathlib import Path

import cv2
import numpy as np
from PIL import Image


def find_sprite_contours(img_bgr, white_threshold=240, min_area=5000):
    """Find individual sprite contours using OpenCV.

    1. Convert to grayscale and threshold to get binary mask
    2. Morphological close to fill small gaps in icon interiors
    3. findContours on the inverted mask (icons = white)
    4. Filter by area to keep only real icons
    5. Return contours sorted in row-major grid order
    """
    gray = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2GRAY)

    _, binary = cv2.threshold(gray, white_threshold, 255, cv2.THRESH_BINARY_INV)

    kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (5, 5))
    binary = cv2.morphologyEx(binary, cv2.MORPH_CLOSE, kernel, iterations=3)

    contours, _ = cv2.findContours(binary, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

    sprites = []
    for cnt in contours:
        area = cv2.contourArea(cnt)
        if area < min_area:
            continue
        x, y, w, h = cv2.boundingRect(cnt)
        if w < 50 or h < 50:
            continue
        sprites.append((cnt, x, y, w, h))

    return sort_sprites_grid(sprites)


def sort_sprites_grid(sprites):
    """Sort sprites into row-major grid order by center coordinates."""
    if not sprites:
        return sprites

    centers = [(y + h / 2, x + w / 2) for (_, x, y, w, h) in sprites]
    heights = [h for (_, x, y, w, h) in sprites]
    avg_h = sum(heights) / len(heights)
    row_tolerance = avg_h * 0.3

    indexed = list(range(len(sprites)))
    indexed.sort(key=lambda i: centers[i][0])

    rows = []
    used = [False] * len(sprites)
    for i in indexed:
        if used[i]:
            continue
        cy = centers[i][0]
        row = [i]
        used[i] = True
        for j in indexed:
            if not used[j] and abs(centers[j][0] - cy) < row_tolerance:
                row.append(j)
                used[j] = True
        row.sort(key=lambda k: centers[k][1])
        rows.append(row)

    result = []
    for row in rows:
        for idx in row:
            result.append(sprites[idx])
    return result


def crop_sprite(img_bgr, contour, bbox, use_alpha=False):
    """Crop a single sprite, optionally with alpha mask for rounded corners."""
    x, y, w, h = bbox

    cropped = img_bgr[y:y + h, x:x + w].copy()

    if use_alpha:
        mask = np.zeros((img_bgr.shape[0], img_bgr.shape[1]), dtype=np.uint8)
        cv2.drawContours(mask, [contour], -1, 255, cv2.FILLED)
        cropped_mask = mask[y:y + h, x:x + w]

        cropped_rgb = cv2.cvtColor(cropped, cv2.COLOR_BGR2RGB)
        rgba = np.dstack([cropped_rgb, cropped_mask])
        return Image.fromarray(rgba, "RGBA")
    else:
        cropped_rgb = cv2.cvtColor(cropped, cv2.COLOR_BGR2RGB)
        return Image.fromarray(cropped_rgb, "RGB")


def split_sprites(
    input_path,
    cols=None,
    rows=None,
    output_dir=None,
    prefix="sprite",
    fmt="png",
    padding="auto",
    margin="auto",
    do_trim=False,
    use_alpha=False,
    names=None,
):
    input_path = Path(input_path)
    if not input_path.exists():
        print(f"Error: input file not found: {input_path}", file=sys.stderr)
        sys.exit(1)

    img_bgr = cv2.imread(str(input_path))
    if img_bgr is None:
        print(f"Error: could not read image: {input_path}", file=sys.stderr)
        sys.exit(1)

    h, w = img_bgr.shape[:2]
    print(f"Image size: {w}x{h}")

    if cols is not None and rows is not None:
        print(f"Using manual grid: {cols}x{rows}")
        sprites = _manual_grid_sprites(img_bgr, rows, cols, padding, margin)
    else:
        print("Auto-detecting sprites via OpenCV contour detection...")
        sprites = find_sprite_contours(img_bgr)
        print(f"Found {len(sprites)} sprites")

    if not sprites:
        print("Error: no sprites detected. Try specifying --cols and --rows.", file=sys.stderr)
        sys.exit(1)

    if output_dir is None:
        output_dir = input_path.parent / f"{input_path.stem}_sprites"
    else:
        output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    name_list = None
    if names:
        name_list = [n.strip() for n in names.split(",")]

    if use_alpha and fmt != "png":
        print("Warning: --alpha requires PNG format, switching to png.", file=sys.stderr)
        fmt = "png"

    count = 0
    for idx, (cnt, x, y, bw, bh) in enumerate(sprites):
        sprite_img = crop_sprite(img_bgr, cnt, (x, y, bw, bh), use_alpha=use_alpha)

        if do_trim and not use_alpha:
            sprite_img = _trim_whitespace(sprite_img)

        if name_list and idx < len(name_list):
            filename = f"{name_list[idx]}.{fmt}"
        else:
            filename = f"{prefix}_{idx:02d}.{fmt}"

        out_path = output_dir / filename
        sprite_img.save(out_path)
        size = sprite_img.size
        mode = "RGBA" if use_alpha else "RGB"
        print(f"  [{idx:2d}] bbox=({x},{y},{x + bw},{y + bh}) {size[0]}x{size[1]} {mode} -> {out_path.name}")
        count += 1

    print(f"\nDone! {count} sprites saved to {output_dir}")
    return count


def _manual_grid_sprites(img_bgr, rows, cols, padding="auto", margin="auto"):
    """Build sprite list from manual grid parameters."""
    h, w = img_bgr.shape[:2]

    if margin == "auto":
        margin_val = _detect_margin(img_bgr)
    else:
        margin_val = int(margin)

    if padding == "auto":
        padding_val = _detect_padding(img_bgr, margin_val)
    else:
        padding_val = int(padding)

    cell_w = (w - 2 * margin_val - (cols - 1) * padding_val) / cols
    cell_h = (h - 2 * margin_val - (rows - 1) * padding_val) / rows

    sprites = []
    for r in range(rows):
        for c in range(cols):
            x = int(margin_val + c * (cell_w + padding_val))
            y = int(margin_val + r * (cell_h + padding_val))
            bw = int(cell_w)
            bh = int(cell_h)
            dummy_cnt = np.array([[x, y], [x + bw, y], [x + bw, y + bh], [x, y + bh]], dtype=np.int32).reshape(-1, 1, 2)
            sprites.append((dummy_cnt, x, y, bw, bh))
    return sprites


def _detect_margin(img_bgr):
    gray = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2GRAY)
    for i in range(gray.shape[0]):
        if np.mean(gray[i, :]) < 245:
            return max(0, i - 1)
    return 0


def _detect_padding(img_bgr, margin_val):
    gray = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2GRAY)
    h = gray.shape[0]
    mid_y = h // 2
    row = gray[mid_y, :]
    white_runs = []
    in_white = False
    start = 0
    for i, v in enumerate(row):
        if v >= 245 and not in_white:
            start = i
            in_white = True
        elif v < 245 and in_white:
            if i - start > 5 and start > margin_val:
                white_runs.append(i - start)
            in_white = False
    if white_runs:
        return int(np.median(white_runs))
    return 0


def _trim_whitespace(img, threshold=245):
    arr = np.array(img)
    if arr.ndim == 2:
        mask = arr < threshold
    else:
        mask = np.any(arr[:, :, :3] < threshold, axis=-1)
    coords = np.argwhere(mask)
    if coords.size == 0:
        return img
    y0, x0 = coords.min(axis=0)
    y1, x1 = coords.max(axis=0) + 1
    return img.crop((x0, y0, x1, y1))


def main():
    parser = argparse.ArgumentParser(description="Split sprite sheet into individual images")
    parser.add_argument("input", help="Input sprite sheet image path")
    parser.add_argument("--cols", type=int, default=None, help="Number of columns (auto-detect if omitted)")
    parser.add_argument("--rows", type=int, default=None, help="Number of rows (auto-detect if omitted)")
    parser.add_argument("--output", default=None, help="Output directory")
    parser.add_argument("--prefix", default="sprite", help="Output filename prefix (default: sprite)")
    parser.add_argument("--format", default="png", dest="fmt", help="Output format: png/jpg/webp (default: png)")
    parser.add_argument("--padding", default="auto", help="Padding between icons in pixels (default: auto)")
    parser.add_argument("--margin", default="auto", help="Margin around edges in pixels (default: auto)")
    parser.add_argument("--trim", action="store_true", help="Trim whitespace from each sprite")
    parser.add_argument("--alpha", action="store_true", help="Save with alpha channel (transparent outside contour)")
    parser.add_argument("--names", default=None, help="Comma-separated names for output files")

    args = parser.parse_args()

    split_sprites(
        input_path=args.input,
        cols=args.cols,
        rows=args.rows,
        output_dir=args.output,
        prefix=args.prefix,
        fmt=args.fmt,
        padding=args.padding,
        margin=args.margin,
        do_trim=args.trim,
        use_alpha=args.alpha,
        names=args.names,
    )


if __name__ == "__main__":
    main()
