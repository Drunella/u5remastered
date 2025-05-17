#!/usr/bin/env python3

# ------------------------------------------------------------------------------
# Copyright 2025 Drunella
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#  http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ------------------------------------------------------------------------------
# This file includes code generated with assistance from ChatGPT,
# a language model by OpenAI.
# ------------------------------------------------------------------------------

"""mapbuilder.py – Assemble a map image from a *block‑based* map file.

Layout hierarchy
================
* **Tile**   – smallest graphic unit (square, *tile_size×tile_size* pixels).
* **Block**  – 16 × 16 tiles ⇒ **256 bytes** in the map file (row‑major indices).
* **Map**    – a *rectangular* grid of blocks (parameter **blocks_width** is mandatory).
* **Optional folding** – When the flag `--fold4` is set, **every group of 4 consecutive
  blocks in a file‑row** is rendered as a **2 × 2 block area** in the output image:

```
file‑row order (4 blocks)   rendered             logical positions
┌─A─┬─B─┬─C─┬─D─┐   ┌─A─┬─B─┐   (row 0, col 0‑1)
                            └─C─┬─D─┘   (row 1, col 0‑1)
```
This halves the map width (in blocks) and doubles its height.

Usage
-----
```bash
python map_builder.py <map_file> <tileset.png> <output.png> <blocks_width> [--tile_size N] [--fold4]
```

Arguments
~~~~~~~~~
* **map_file**      – binary file, 256 B per block.
* **tileset.png**   – sprite sheet containing at least the first 256 tiles.
* **output.png**    – where to save the final image.
* **blocks_width**  – *integer*, number of blocks per file‑row.
* `--tile_size N`   – pixel size of one tile edge (default **16**).
* `--fold4`         – enable 4‑block‑to‑2×2 folding.

Output size without folding = `(blocks_width × 16) × (blocks_height × 16)` tiles.
With `--fold4`              = `(blocks_width/2 × 16) × (blocks_height×2 × 16)` tiles.
(All multiplied by *tile_size* for pixels.)
"""

from __future__ import annotations
import argparse, math, sys
from pathlib import Path
from PIL import Image

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
BLOCK_SIDE  = 16                 # tiles per block edge
BLOCK_TILES = BLOCK_SIDE ** 2    # 256 tiles / bytes per block
MAX_TILE_INDEX = 255             # we only use the first 256 tiles

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def load_map(path: Path):
    data = path.read_bytes()
    if len(data) % BLOCK_TILES:
        raise ValueError("Map length must be a multiple of 256 bytes (one block).")
    return data, len(data) // BLOCK_TILES  # (bytes, total_blocks)


def slice_tiles(tileset: Image.Image, tile_size: int, needed: int = 256):
    if tileset.width % tile_size or tileset.height % tile_size:
        raise ValueError("Tileset dimensions must be multiples of the tile size.")
    cols = tileset.width // tile_size
    rows = math.ceil(needed / cols)
    tiles: list[Image.Image] = []
    for r in range(rows):
        for c in range(cols):
            if len(tiles) == needed:
                return tiles
            box = (c * tile_size, r * tile_size, (c + 1) * tile_size, (r + 1) * tile_size)
            tiles.append(tileset.crop(box))
    raise ValueError(f"Tileset provides only {len(tiles)} tiles; {needed} required.")

# ---------------------------------------------------------------------------
# Image assembly
# ---------------------------------------------------------------------------

def build_image(
    data: bytes,
    blocks_w: int,
    blocks_h: int,
    tiles: list[Image.Image],
    tile_size: int,
    fold4: bool,
):
    """Return the assembled map as a Pillow RGBA image."""

    if fold4 and blocks_w % 4:
        raise ValueError("--fold4 enabled but blocks_width is not divisible by 4.")

    dst_blocks_w = (blocks_w // 4 * 2) if fold4 else blocks_w
    dst_blocks_h = (blocks_h * 2) if fold4 else blocks_h

    canvas = Image.new("RGBA", (dst_blocks_w * BLOCK_SIDE * tile_size, dst_blocks_h * BLOCK_SIDE * tile_size))

    for br in range(blocks_h):
        for bc in range(blocks_w):
            block_index = br * blocks_w + bc
            block_offset = block_index * BLOCK_TILES

            # Determine destination block coordinates (dest_br, dest_bc)
            if fold4:
                group_col   = bc // 4
                within      = bc % 4  # 0,1,2,3
                row_off     = within // 2  # 0 or 1
                col_off     = within % 2   # 0 or 1
                dest_bc     = group_col * 2 + col_off
                dest_br     = br * 2 + row_off
            else:
                dest_bc     = bc
                dest_br     = br

            for inside in range(BLOCK_TILES):
                idx = data[block_offset + inside]
                if idx > MAX_TILE_INDEX:
                    raise ValueError(
                        f"Tile index {idx} out of range 0‑255 at byte {block_offset + inside}."
                    )
                tr = inside // BLOCK_SIDE  # tile row inside block
                tc = inside % BLOCK_SIDE   # tile col inside block
                px = (dest_bc * BLOCK_SIDE + tc) * tile_size
                py = (dest_br * BLOCK_SIDE + tr) * tile_size
                canvas.paste(tiles[idx], (px, py))
    return canvas, dst_blocks_w, dst_blocks_h

# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def parse_args():
    p = argparse.ArgumentParser(description="Create a map image from a block‑based map file.")
    p.add_argument("map_file", type=Path, help="Binary map file (block‑based).")
    p.add_argument("tileset_image", type=Path, help="Tileset sprite sheet (≥256 tiles).")
    p.add_argument("output_image", type=Path, help="Destination image path.")
    p.add_argument("blocks_width", type=int, help="Number of blocks per file‑row in the map.")
    p.add_argument("--tile_size", type=int, default=16, metavar="N", help="Tile edge length in pixels (default 16).")
    p.add_argument("--fold4", action="store_true", help="Fold every 4 blocks in a row into a 2×2 area.")
    return p.parse_args()

# ---------------------------------------------------------------------------
# Main entry
# ---------------------------------------------------------------------------

def main():
    args = parse_args()
    try:
        data, total_blocks = load_map(args.map_file)
        if args.blocks_width <= 0:
            raise ValueError("blocks_width must be a positive integer.")
        if total_blocks % args.blocks_width:
            raise ValueError(
                f"File has {total_blocks} blocks, which is not divisible by blocks_width={args.blocks_width}."
            )
        blocks_height = total_blocks // args.blocks_width

        tileset = Image.open(args.tileset_image).convert("RGBA")
        tiles = slice_tiles(tileset, args.tile_size)
        img, out_bw, out_bh = build_image(
            data,
            args.blocks_width,
            blocks_height,
            tiles,
            args.tile_size,
            args.fold4,
        )
        img.save(args.output_image)

        print(
            f"Saved {args.output_image} – {img.width}×{img.height}px (blocks {out_bw}×{out_bh}, "
            f"{img.width // args.tile_size}×{img.height // args.tile_size} tiles)."
        )
    except Exception as exc:
        print(f"Error: {exc}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
