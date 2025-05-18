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

"""roombuilder.py – Render an 11×11-tile map (121 bytes) to a PNG.

A handful of legacy maps are stored as **256-byte** blobs where only the first
*11 × 11 = 121* bytes are meaningful tile indices.  The remaining 135 bytes are
ignored.

Usage
-----
```bash
python map11_builder.py <map_file> <tileset.png> <output.png> [--tile_size 16]
```

* **map_file**    – binary file; at least 121 bytes long (only the first 121 are used).
* **tileset.png** – image containing a grid of 16×16 tiles (or whatever `--tile_size` is).
                   Only the first 256 tiles matter.
* **output.png**  – destination image path.
* `--tile_size`   – size of one tile edge in pixels (default **16**).

Result: a PNG that is `11 × 11` tiles ⇒ `(11 * tile_size)²` pixels.
"""

from __future__ import annotations
import argparse, math, sys
from pathlib import Path
from PIL import Image

# ---------------------------------------------------------------------------
TILES_PER_ROW = 11      # map width / height in tiles
MAP_BYTES     = 121     # meaningful bytes in the map file (11×11)
MAX_TILE_IDX  = 255     # we only care about first 256 tiles in the tileset

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def read_map(path: Path) -> bytes:
    """Return exactly 121 bytes (pad with zeros if file shorter)."""
    data = path.read_bytes()
    if len(data) < MAP_BYTES:
        raise ValueError(f"Map file too short: need {MAP_BYTES} bytes, got {len(data)}.")
    return data[:MAP_BYTES]


def slice_tiles(tileset: Image.Image, tile_sz: int, needed: int = 256):
    if tileset.width % tile_sz or tileset.height % tile_sz:
        raise ValueError("Tileset size must be a multiple of tile_size.")
    cols = tileset.width // tile_sz
    rows = math.ceil(needed / cols)
    tiles: list[Image.Image] = []
    for r in range(rows):
        for c in range(cols):
            if len(tiles) == needed:
                return tiles
            box = (c*tile_sz, r*tile_sz, (c+1)*tile_sz, (r+1)*tile_sz)
            tiles.append(tileset.crop(box))
    raise ValueError(f"Tileset provides only {len(tiles)} tiles; {needed} required.")

# ---------------------------------------------------------------------------
# Main logic
# ---------------------------------------------------------------------------

def build_image(map_bytes: bytes, tiles: list[Image.Image], tile_sz: int):
    canvas = Image.new("RGBA", (TILES_PER_ROW * tile_sz, TILES_PER_ROW * tile_sz))
    for i, idx in enumerate(map_bytes):
        if idx > MAX_TILE_IDX:
            raise ValueError(f"Tile index {idx} out of range (0-255) at byte {i}.")
        row = i // TILES_PER_ROW
        col = i % TILES_PER_ROW
        canvas.paste(tiles[idx], (col * tile_sz, row * tile_sz))
    return canvas

# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def parse_args():
    p = argparse.ArgumentParser(description="Render an 11×11-tile map (121 bytes) to a PNG.")
    p.add_argument("map_file", type=Path, help="Binary map file (≥121 bytes, first 121 used).")
    p.add_argument("tileset", type=Path, help="Tileset image (grid, ≥256 tiles).")
    p.add_argument("output", type=Path, help="Destination PNG path.")
    p.add_argument("--tile_size", type=int, default=16, help="Tile edge length in pixels (default 16).")
    return p.parse_args()


def main():
    args = parse_args()
    try:
        map_bytes = read_map(args.map_file)
        tileset_img = Image.open(args.tileset).convert("RGBA")
        tiles = slice_tiles(tileset_img, args.tile_size)
        image = build_image(map_bytes, tiles, args.tile_size)
        image.save(args.output)
        print(
            f"✔ Saved {args.output} – {image.width}×{image.height}px (11×11 tiles)."
        )
    except Exception as exc:
        print(f"Error: {exc}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
