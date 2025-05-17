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

"""
font2png.py  –  Convert a 256-glyph 1-bit C-64 font dump to a 16×16 PNG.

Each glyph is 8×8 pixels stored as 8 bytes, MSB = leftmost pixel.
The 256 glyphs are assumed to be in simple ascending order (0–255).

Example
-------
$ python font2png.py c64font.bin -o c64font.png -s 4
"""

import argparse
from pathlib import Path
from PIL import Image

BYTES_PER_TILE = 8        # 8 bytes = 8 rows
TILE_SIDE      = 8        # 8×8 pixels per tile
TILES          = 256      # fixed
GRID_SIDE      = 16       # 16×16 tiles
IMG_SIZE       = GRID_SIDE * TILE_SIDE  # 128×128 px

WHITE = (255, 255, 255)
BLACK = (0, 0, 0)


def parse_cli() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Convert 1-bit font dump to PNG.")
    p.add_argument("input",  help="2048-byte raw bitmap file")
    p.add_argument("-o", "--output", help="PNG to write",
                   default="font.png")
    p.add_argument("-s", "--scale", type=int, default=1,
                   help="integer up-scaling factor (nearest-neighbour)")
    return p.parse_args()


def load_font(path: Path) -> bytes:
    data = path.read_bytes()
    expected = TILES * BYTES_PER_TILE
    if len(data) != expected:
        raise ValueError(f"{path} must be {expected} bytes (got {len(data)})")
    return data


def render_sheet(font: bytes) -> Image.Image:
    img = Image.new("RGB", (IMG_SIZE, IMG_SIZE), BLACK)
    px  = img.load()

    for tile_idx in range(TILES):
        tile_off = tile_idx * BYTES_PER_TILE
        tile     = font[tile_off : tile_off + BYTES_PER_TILE]

        col =  tile_idx % GRID_SIDE
        row = (tile_idx // GRID_SIDE)
        x0, y0 = col * TILE_SIDE, row * TILE_SIDE

        for y in range(TILE_SIDE):
            byte = tile[y]
            for x in range(TILE_SIDE):
                if (byte >> (7 - x)) & 1:
                    px[x0 + x, y0 + y] = WHITE
    return img


def main() -> None:
    args  = parse_cli()
    font  = load_font(Path(args.input))
    sheet = render_sheet(font)

    if args.scale != 1:
        w, h = sheet.size
        sheet = sheet.resize((w * args.scale, h * args.scale),
                             Image.NEAREST)

    sheet.save(args.output)
    print(f"Saved {args.output} ({sheet.width}×{sheet.height}px)")


if __name__ == "__main__":
    main()
