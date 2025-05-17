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
gembuilder.py – convert a 256‑byte‑block map file to a PNG composed of
8 × 8 C‑64 tiles, using YAML for both the tileset and the transform
(table).

——————————————————————————————————————————————————————————————
Layout modes
——————————————————————————————————————————————————————————————
* **normal** – blocks are placed directly in a grid *width‑blocks* wide
  (default 16).
* **2x2** – every four consecutive blocks in the map file form a 2 × 2
  *supertile* (32 × 32 tiles).  Supertile groups are laid out
  left‑to‑right, top‑to‑bottom.  In this mode the image width defaults to
  **8 blocks** (4 supertiles) unless you specify
  `--width-blocks <even number>` explicitly.

——————————————————————————————————————————————————————————————
YAML formats (unchanged)
——————————————————————————————————————————————————————————————
See the headed examples in this file for *tileset.yaml* and
*transform.yaml*.

——————————————————————————————————————————————————————————————
Usage (unchanged)
——————————————————————————————————————————————————————————————
```bash
pip install pillow pyyaml

# normal layout (16 blocks across)
python map2png.py level.map tileset.yaml -o level.png

# 2×2 layout (defaults to 8 blocks across = 4 supertiles)
python map2png.py level.map tileset.yaml --layout 2x2 -o level2.png
```
"""

from __future__ import annotations

import argparse
from pathlib import Path
from typing import List, Sequence

import yaml  # PyYAML
from PIL import Image

# ---------------------------------------------------------------------
# Fixed C‑64 palette (RGB)
# ---------------------------------------------------------------------
C64_PALETTE = [
    (0x00, 0x00, 0x00),  # 0 black
    (0xFF, 0xFF, 0xFF),  # 1 white
    (0x68, 0x37, 0x2B),  # 2 red
    (0x70, 0xA4, 0xB2),  # 3 cyan
    (0x6F, 0x3D, 0x86),  # 4 purple
    (0x58, 0x8D, 0x43),  # 5 green
    (0x35, 0x28, 0x79),  # 6 blue
    (0xB8, 0xC7, 0x6F),  # 7 yellow
    (0x6F, 0x4F, 0x25),  # 8 orange
    (0x43, 0x39, 0x00),  # 9 brown
    (0x9A, 0x67, 0x59),  # 10 light‑red
    (0x44, 0x44, 0x44),  # 11 dark‑grey
    (0x6C, 0x6C, 0x6C),  # 12 grey
    (0x9A, 0xD2, 0x84),  # 13 light‑green
    (0x6C, 0x5E, 0xB5),  # 14 light‑blue
    (0x95, 0x95, 0x95),  # 15 light‑grey
]

_palette_img = Image.new("P", (1, 1))
_palette_bytes: list[int] = []
for r, g, b in C64_PALETTE:
    _palette_bytes.extend((r, g, b))
_palette_img.putpalette(_palette_bytes * 16)

# ---------------------------------------------------------------------
# YAML helpers
# ---------------------------------------------------------------------

def _load_yaml(path: Path):
    try:
        return yaml.safe_load(path.read_text())
    except yaml.YAMLError as exc:
        raise ValueError(f"Failed to parse YAML in {path}: {exc}") from exc

# ---------------------------------------------------------------------
# Transform table (256 ints)
# ---------------------------------------------------------------------

def read_transform(path: Path | None) -> Sequence[int]:
    if path is None:
        return list(range(256))

    data = _load_yaml(path)
    if isinstance(data, dict):
        try:
            data = next(v for v in data.values() if isinstance(v, list))
        except StopIteration:
            raise ValueError("Transform YAML must contain a 256‑integer list")

    if not isinstance(data, list) or len(data) != 256:
        raise ValueError("Transform YAML must be exactly 256 integers")

    try:
        return [int(x) & 0xFF for x in data]
    except Exception:
        raise ValueError("Transform entries must be integers (0‑255)")

# ---------------------------------------------------------------------
# Tileset
# ---------------------------------------------------------------------

def _parse_bitmap(raw) -> List[int]:
    if isinstance(raw, list):
        if len(raw) != 8:
            raise ValueError("Bitmap list must have 8 bytes")
        return [int(b) & 0xFF for b in raw]
    if isinstance(raw, str):
        tokens = raw.replace(",", " ").split()
        if len(tokens) != 8:
            raise ValueError("Bitmap string must list 8 bytes")
        return [int(tok, 0) & 0xFF for tok in tokens]
    raise ValueError("Bitmap must be list[8] or string of 8 numbers")

def read_tileset(path: Path) -> List[Image.Image]:
    doc = _load_yaml(path)
    tiles_raw = doc.get("tiles") if isinstance(doc, dict) else doc
    if not isinstance(tiles_raw, list):
        raise ValueError("Tileset YAML must contain a 'tiles' list or be a list")

    tiles: list[Image.Image] = []
    for idx, tile in enumerate(tiles_raw):
        if not isinstance(tile, dict):
            raise ValueError(f"Tile {idx} is not a mapping")
        bitmap = _parse_bitmap(tile.get("bitmap"))
        colour = int(tile.get("colour"))
        if not 0 <= colour <= 15:
            raise ValueError(f"Tile {idx}: colour must be 0‑15")

        img = Image.new("P", (8, 8))
        img.putpalette(_palette_img.palette)
        px = img.load()
        for y, byte in enumerate(bitmap):
            for x in range(8):
                bit = (byte >> (7 - x)) & 1
                px[x, y] = colour if bit else 0
        tiles.append(img)

    if not tiles:
        raise ValueError("Tileset contains no tiles")
    return tiles

# ---------------------------------------------------------------------
# PNG assembly
# ---------------------------------------------------------------------

def build_image(
    blocks: List[bytes],
    tiles: Sequence[Image.Image],
    transform: Sequence[int],
    width_blocks: int,
    layout: str,
) -> Image.Image:
    # verify block sizes
    for i, blk in enumerate(blocks):
        if len(blk) != 256:
            raise ValueError(f"Block {i} length is {len(blk)} bytes, expected 256")

    if layout == "2x2":
        if width_blocks % 2:
            raise ValueError("width‑blocks must be even in 2x2 mode")
        super_per_row = width_blocks // 2
        if len(blocks) % 4:
            raise ValueError("Map size must be a multiple of 4 blocks in 2x2 mode")
    else:
        if len(blocks) % width_blocks:
            raise ValueError("width‑blocks does not divide block count in normal mode")

    # compute output dimensions (in tiles)
    if layout == "normal":
        width_tiles = width_blocks * 16
        height_tiles = (len(blocks) // width_blocks) * 16
    else:  # 2×2 mode
        groups = len(blocks) // 4  # number of supertiles
        rows_super = (groups + super_per_row - 1) // super_per_row  # ceil division
        width_tiles = width_blocks * 16  # e.g. 8 blocks → 128 tiles
        height_tiles = rows_super * 32  # each supertile is 2 blocks (32 tiles) high

    canvas = Image.new("RGB", (width_tiles * 8, height_tiles * 8))

    for bidx, block in enumerate(blocks):
        if layout == "normal":
            bx = bidx % width_blocks
            by = bidx // width_blocks
        else:  # 2×2 mode
            group_idx = bidx // 4           # which supertile
            pos_in_group = bidx & 3         # 0‑3 within that supertile
            gx = group_idx % super_per_row  # supertile X
            gy = group_idx // super_per_row # supertile Y
            bx = gx * 2 + (pos_in_group & 1)# block X (0 or 1 inside supertile)
            by = gy * 2 + (pos_in_group >> 1)# block Y (0 or 1 inside supertile)

        for tidx, byte in enumerate(block):
            tx, ty = tidx & 0x0F, tidx >> 4   # 0‑15 within block
            gx = bx * 16 + tx
            gy = by * 16 + ty
            tile_id = transform[byte]
            try:
                tile_img = tiles[tile_id]
            except IndexError as exc:
                raise IndexError(f"Tile index {tile_id} out of range") from exc
            canvas.paste(tile_img.convert("RGB"), (gx * 8, gy * 8))

    return canvas

# ---------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------

def main() -> None:
    ap = argparse.ArgumentParser(
        description="Convert 256‑byte‑block map to PNG with YAML tileset & transform"
    )
    ap.add_argument("mapfile", type=Path, help="binary map file (.map)")
    ap.add_argument("tileset", type=Path, help="tileset YAML file")
    ap.add_argument("-o", "--output", type=Path, default=Path("out.png"), help="output PNG filename")
    ap.add_argument("--transform", type=Path, help="transform YAML (default identity)")
    ap.add_argument(
        "--width-blocks",
        type=int,
        default=16,
        help="map width in 256‑byte blocks (default 16, or 8 for 2×2 when omitted)",
    )
    ap.add_argument("--layout", choices=["normal", "2x2"], default="normal", help="layout mode")

    args = ap.parse_args()

    # In 2×2 mode switch default width from 16→8 if the user left it unchanged.
    if args.layout == "2x2" and args.width_blocks == 16:
        args.width_blocks = 8

    transform = read_transform(args.transform)
    tiles = read_tileset(args.tileset)

    raw = args.mapfile.read_bytes()
    if raw.__len__() % 256:
        raise ValueError("Map file size must be a multiple of 256 bytes")
    blocks = [raw[i : i + 256] for i in range(0, len(raw), 256)]

    img = build_image(blocks, tiles, transform, args.width_blocks, args.layout)
    img.save(args.output)
    print(f"Saved {args.output}  ({img.width}×{img.height})")


if __name__ == "__main__":
    main()
