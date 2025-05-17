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
C-64 hi-res tile viewer – *2×2-square aware*

Data layout:

• 4 × 4096-byte files  →  2048 tiles total
  – each tile = 8 bytes (8 × 8 1-bit pixels)
  – **tiles 0-3, 4-7, … inside *each* file form 2 × 2 blocks on screen**

• 1 × 2048-byte colour file
  – one byte per tile (low nibble = background, high = foreground)

Edit TILE_FILES / COLOR_FILE below and run the script.
"""

from pathlib import Path
from math import ceil
from PIL import Image

# ──────────────────────────────────────────────────────────
# 1.  FILE NAMES  – put yours here
# ──────────────────────────────────────────────────────────
TILE_FILES = [
    "./build/png/s0.bin",
    "./build/png/s1.bin",
    "./build/png/s2.bin",
    "./build/png/s3.bin",
]

COLOR_FILE = "./build/png/colors.bin"      # ← 2048 bytes

# ──────────────────────────────────────────────────────────
# 2.  CONSTANTS
# ──────────────────────────────────────────────────────────
PEPTO_PALETTE = [                    # Authentic C-64 RGB palette
    (  0,   0,   0), (255, 255, 255), (136,   0,   0), (170, 255, 238),
    (204,  68, 204), (  0, 204,  85), (  0,   0, 170), (238, 238, 119),
    (221, 136,  85), (102,  68,   0), (255, 119, 119), ( 51,  51,  51),
    (119, 119, 119), (170, 255, 102), (  0, 136, 255), (187, 187, 187),
]

BYTES_PER_TILE  = 8
TILES_PER_FILE  = 4096 // BYTES_PER_TILE          # 512
TOTAL_TILES     = TILES_PER_FILE * len(TILE_FILES)

TILES_PER_ROW   = 40                              # 320 px wide just like a C-64
QUADS_PER_ROW   = TILES_PER_ROW // 2              # 20 two-by-two blocks per row

QUAD_COUNT      = TOTAL_TILES // 4
QUAD_ROWS       = ceil(QUAD_COUNT / QUADS_PER_ROW)
ROWS            = QUAD_ROWS * 2                   # tiles: 2 rows per quad row

IMG_W, IMG_H    = TILES_PER_ROW * 8, ROWS * 8

# ──────────────────────────────────────────────────────────
# 3.  LOAD DATA & BASIC SANITY CHECKS
# ──────────────────────────────────────────────────────────
tile_bytes = bytearray()
for fname in TILE_FILES:
    data = Path(fname).read_bytes()
    if len(data) != 4096:
        raise ValueError(f"{fname}: expected 4096 B, got {len(data)}")
    tile_bytes.extend(data)

if len(tile_bytes) != TOTAL_TILES * BYTES_PER_TILE:
    raise AssertionError("Tile data wrong size")

colour_bytes = Path(COLOR_FILE).read_bytes()
if len(colour_bytes) != TOTAL_TILES:
    raise ValueError(f"{COLOR_FILE}: expected 2048 B, got {len(colour_bytes)}")

# ──────────────────────────────────────────────────────────
# 4.  POSITION-MAPPING HELPERS
# ──────────────────────────────────────────────────────────
def tile_to_grid(tile_idx: int) -> tuple[int, int]:
    """
    Convert a *sequential* tile index (0-2047) to (col,row) on the preview,
    honouring the 2×2 grouping: tiles 0-3 form a square, 4-7 the next, etc.
    """
    local_id = tile_idx & 3         # 0–3 inside its 2×2 square
    local_x  =  local_id  & 1       # 0 or 1
    local_y  = (local_id >> 1)      # 0 or 1

    quad_idx = tile_idx >> 2        # which 2×2 square overall (0-511)
    q_col    = quad_idx % QUADS_PER_ROW
    q_row    = quad_idx // QUADS_PER_ROW

    col = q_col * 2 + local_x       # 0-39
    row = q_row * 2 + local_y       # 0-51
    return col, row

# ──────────────────────────────────────────────────────────
# 5.  RENDER TILES INTO A SINGLE IMAGE
# ──────────────────────────────────────────────────────────
img = Image.new("RGB", (IMG_W, IMG_H))
pixels = img.load()

for tile_idx in range(TOTAL_TILES):
    tile_start = tile_idx * BYTES_PER_TILE
    tile_data  = tile_bytes[tile_start : tile_start + BYTES_PER_TILE]

    colour     = colour_bytes[tile_idx]
    bg_col     = PEPTO_PALETTE[colour & 0x0F]
    fg_col     = PEPTO_PALETTE[colour >> 4]

    col, row   = tile_to_grid(tile_idx)
    px0, py0   = col * 8, row * 8

    for y in range(8):
        byte = tile_data[y]
        for x in range(8):
            bit = (byte >> (7 - x)) & 1
            pixels[px0 + x, py0 + y] = fg_col if bit else bg_col

# ──────────────────────────────────────────────────────────
# 6.  SHOW & SAVE
# ──────────────────────────────────────────────────────────
#img.show()
img.save("build/png/tiles.png")
print("written to tiles.png")
