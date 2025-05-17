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
dungeonbuilder.py – Convert an 8‑level binary map (8 × 8 fields per level, **one byte per field**) into a
composite PNG.

Version 2 – **Byte‑level mapping**
================================
The tile selection is now based on the **full byte value** (0–255).  The previous upper/lower‑nibble
layering is gone, so every byte directly corresponds to exactly **one** glyph.  Optionally tint that
glyph by adding a `colour` field.

USAGE
-----
```bash
python map2png.py MAP.BIN FONT.PNG MAPPING.YAML OUTPUT.PNG [--scale N] [--no-sep]
```
* *MAP.BIN*  – 512‑byte binary (8 levels × 64 bytes).
* *FONT.PNG* – 256‑glyph atlas (16 × 16 grid, every glyph 8 × 8 px).
* *MAPPING.YAML/JSON* – dictionary **byte‑value→{glyph, colour?}**.
* *OUTPUT.PNG* – destination image file.

Options
~~~~~~~
```
-s, --scale N   Nearest‑neighbour upscale factor (default 4).
--no-sep        Disable separator lines.
```

Mapping file
~~~~~~~~~~~~
* Keys: 0–255 (decimal) **or** `0x00`–`0xFF` (hex strings).
* Value object fields:
  * `glyph` – integer 0–255 (index into the 16 × 16 atlas). **Required.**
  * `colour` – `#RRGGBB` (optional).  If omitted, the glyph is copied unchanged.

Example
^^^^^^^
```yaml
0x00: {glyph: 0,   colour: "#202020"}  # dark floor tile
0x01: {glyph: 2,   colour: "#606060"}  # wall
0x10: {glyph: 65,  colour: "#FF0000"}  # red key (different byte value)
0x11: {glyph: 66}                       # yellow key, no tint (atlas colours)
```

Unmapped bytes render as fully transparent (blank).

Dependencies
~~~~~~~~~~~~
* Pillow – `pip install pillow`
* PyYAML – optional, only needed for YAML mapping files.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any, Dict

from PIL import Image, ImageDraw

try:
    import yaml  # type: ignore

    _HAS_YAML = True
except ImportError:
    _HAS_YAML = False

JSONDecodeError = getattr(json, "JSONDecodeError", ValueError)

# ---------------------------------------------------------------------------
# Utility helpers
# ---------------------------------------------------------------------------

def _parse_hex_colour(value: str | None) -> tuple[int, int, int] | None:
    """Return (R, G, B) from a #RRGGBB string or ``None`` if *value* is None."""
    if value is None:
        return None
    value = value.strip().lstrip("#")
    if len(value) != 6 or any(c not in "0123456789abcdefABCDEF" for c in value):
        raise ValueError(f"Invalid colour literal: {value!r}")
    return tuple(int(value[i : i + 2], 16) for i in (0, 2, 4))  # type: ignore[return-value]


class MappingError(Exception):
    """Raised when the mapping file is malformed."""


# ---------------------------------------------------------------------------
# Mapping loader
# ---------------------------------------------------------------------------

def _load_mapping(path: Path) -> Dict[int, Dict[str, Any]]:
    """Return a mapping *byte_value → spec* where *spec* has keys ``glyph`` and optional ``colour``."""
    try:
        raw = path.read_text("utf-8")
    except FileNotFoundError as exc:
        raise MappingError(f"Mapping file '{path}' not found.") from exc

    # Parse JSON or YAML ---------------------------------------------------
    try:
        if path.suffix.lower() in {".yaml", ".yml"}:
            if not _HAS_YAML:
                raise MappingError("PyYAML is not installed – install it or provide JSON instead.")
            data = yaml.safe_load(raw)
        else:
            data = json.loads(raw)
    except (JSONDecodeError, yaml.YAMLError) as exc:  # type: ignore[arg-type]
        raise MappingError(f"Failed to parse mapping file: {exc}") from exc

    if not isinstance(data, dict):
        raise MappingError("Mapping root must be an object/dictionary.")

    mapping: Dict[int, Dict[str, Any]] = {}
    for k, v in data.items():
        # Accept both string (e.g. "0x1A" or "26") **and** integer keys
        if isinstance(k, int):
            key_int = k
        else:
            try:
                key_int = int(str(k), 0)  # auto‑detect 0x.. or decimal strings
            except ValueError as exc:
                raise MappingError(f"Invalid byte key {k!r}; must be 0–255 or 0x00–0xFF.") from exc

        if not (0 <= key_int <= 0xFF):
            raise MappingError(f"Byte key {k!r} is outside 0x00–0xFF.")
        if not isinstance(v, dict):
            raise MappingError(f"Mapping for byte {k!r} must be an object.")

        glyph = v.get("glyph")
        if not isinstance(glyph, int) or not (0 <= glyph <= 255):
            raise MappingError(f"Invalid or missing 'glyph' for byte {k!r}.")

        colour_literal = v.get("colour")
        try:
            colour_rgb = _parse_hex_colour(colour_literal)
        except ValueError as exc:
            raise MappingError(f"Invalid colour for byte {k!r}: {colour_literal!r}") from exc

        mapping[key_int] = {"glyph": glyph, "colour": colour_rgb}

    return mapping


# ---------------------------------------------------------------------------
# Graphics helpers
# ---------------------------------------------------------------------------

def _extract_glyph(atlas: Image.Image, index: int) -> Image.Image:
    """Return a single 8 × 8 glyph from the 16 × 16 atlas."""
    if not (0 <= index <= 255):
        raise ValueError("Glyph index must be 0–255.")
    row, col = divmod(index, 16)
    x0, y0 = col * 8, row * 8
    return atlas.crop((x0, y0, x0 + 8, y0 + 8))


def _tint_glyph(glyph: Image.Image, colour: tuple[int, int, int]) -> Image.Image:
    """Colourise *glyph* while preserving black background.

    Strategy:
        • If glyph already has transparency → use alpha as mask (no change).
        • Else (fully opaque 1‑bit/monochrome atlas) → build a *binary* mask:
            – Pixels with luminance > 128 (i.e. light/white) are treated as *glyph* → coloured.
            – Pixels ≤ 128 (dark/black) are treated as background → remain untouched.

    This prevents dark pixels from being tinted and keeps solid black areas black.
    """
    if glyph.mode != "RGBA":
        glyph = glyph.convert("RGBA")

    r, g, b, a = glyph.split()
    if a.getextrema() != (255, 255):
        # Existing transparency – just tint opaque pixels using alpha as mask
        mask = a
    else:
        # Fully opaque → derive binary mask from brightness (white = glyph)
        lum = Image.merge("RGB", (r, g, b)).convert("L")
        # Create mask: 255 for bright pixels, 0 otherwise
        mask = lum.point(lambda x: 255 if x > 128 else 0, mode="1").convert("L")

    tinted = Image.new("RGBA", glyph.size, (*colour, 0))
    tinted.putalpha(mask)
    # Composite tinted colour over original glyph so black pixels stay black
    base = glyph.copy()
    base.alpha_composite(tinted)
    return base


# ---------------------------------------------------------------------------
# Tile renderer
# ---------------------------------------------------------------------------

def _render_tile(atlas: Image.Image, mapping: Dict[int, Dict[str, Any]], byte_value: int) -> Image.Image:
    """Return an 8 × 8 RGBA tile for *byte_value* using *mapping* (or blank if unmapped)."""
    spec = mapping.get(byte_value)
    if spec is None:
        return Image.new("RGBA", (8, 8), (0, 0, 0, 0))  # transparent

    glyph = _extract_glyph(atlas, spec["glyph"])
    colour = spec["colour"]
    if colour is not None:
        glyph = _tint_glyph(glyph, colour)
    return glyph


# ---------------------------------------------------------------------------
# Main entry
# ---------------------------------------------------------------------------

def main() -> None:  # noqa: C901
    parser = argparse.ArgumentParser(description="Render MAP.BIN into composite PNG using byte‑level mapping")
    parser.add_argument("map", type=Path, help="binary map file (512 bytes)")
    parser.add_argument("font", type=Path, help="256‑glyph 16×16 atlas PNG")
    parser.add_argument("mapping", type=Path, help="byte→glyph mapping file (YAML/JSON)")
    parser.add_argument("output", type=Path, help="output PNG path")
    parser.add_argument("-s", "--scale", type=int, default=4, metavar="N", help="upscale factor (default 4)")
    parser.add_argument("--no-sep", action="store_true", help="disable grid separator lines")
    args = parser.parse_args()

    if args.scale < 1:
        sys.exit("Error: --scale must be ≥ 1")

    # ------------------------------------------------------------------
    # Load files
    # ------------------------------------------------------------------
    try:
        data = args.map.read_bytes()
    except FileNotFoundError:
        sys.exit(f"Error: map file '{args.map}' not found.")
    if len(data) != 512:
        sys.exit("Error: map file must be exactly 512 bytes (8 levels × 64 bytes).")

    try:
        atlas = Image.open(args.font).convert("RGBA")
    except Exception as exc:
        sys.exit(f"Error opening atlas '{args.font}': {exc}")

    try:
        mapping = _load_mapping(args.mapping)
    except MappingError as exc:
        sys.exit(f"Mapping error: {exc}")

    # ------------------------------------------------------------------
    # Render each level (64 × 64 px)
    # ------------------------------------------------------------------
    levels: list[Image.Image] = []
    for lvl_no in range(8):
        lvl_img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
        slice_bytes = data[lvl_no * 64 : (lvl_no + 1) * 64]
        for offset, byte_val in enumerate(slice_bytes):
            row, col = divmod(offset, 8)
            tile = _render_tile(atlas, mapping, byte_val)
            lvl_img.paste(tile, (col * 8, row * 8), tile)
        levels.append(lvl_img)

    # ------------------------------------------------------------------
    # Compose 3 × 3 grid (cell (2,2) left blank)
    # ------------------------------------------------------------------
    base_grid = Image.new("RGBA", (192, 192), (0, 0, 0, 0))
    for idx, lvl in enumerate(levels):
        r, c = divmod(idx, 3)
        base_grid.paste(lvl, (c * 64, r * 64))

    grid = base_grid.resize((base_grid.width * args.scale, base_grid.height * args.scale), Image.NEAREST) if args.scale > 1 else base_grid

    if not args.no_sep:
        draw = ImageDraw.Draw(grid)
        line_colour = (128, 128, 128, 255)
        for pos in (64, 128):
            p = pos * args.scale
            draw.line([(p, 0), (p, grid.height)], fill=line_colour, width=1)
            draw.line([(0, p), (grid.width, p)], fill=line_colour, width=1)

    try:
        grid.save(args.output)
    except Exception as exc:
        sys.exit(f"Failed to save output image: {exc}")
    print(f"Saved {args.output}")


if __name__ == "__main__":
    main()
