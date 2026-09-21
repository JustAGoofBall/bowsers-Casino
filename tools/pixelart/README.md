# Pixel art generators

Every sprite under `assets/pixel/` is produced by these scripts, so the art is
editable as source rather than as flattened PNGs. Nothing outside the standard
library is needed.

```
python3 tools/pixelart/gen_pieces.py   # chips, ball, dice, peg, marker, pip, HELD tag
python3 tools/pixelart/gen_cards.py    # the 53-card deck
python3 tools/pixelart/gen_boss.py     # the four house-boss poses
```

- `pixlib.py` holds the locked palette and the drawing canvas. Every sprite
  draws only from `PALETTE`, which is what makes separately-drawn pieces read
  as one set; `Canvas.set` refuses a colour that is not in it.
- `pixfont.py` holds the 3x5 font and the four suit pips.

## Native sizes and scales

The sprites are small and are drawn at whole-number scales, because a
fractional scale makes pixels uneven however good the filtering is.

| sprite      | native | drawn at        |
|-------------|--------|-----------------|
| card        | 32x44  | 3x poker/blackjack, 4x hi-lo |
| boss        | 48x44  | 3x craps, 4x elsewhere, 10x blackjack |
| chip        | 24x24  | 2x              |
| die         | 20x20  | 4x              |
| ball        | 12x12  | 2x              |
| peg         | 10x10  | 2x              |
| wheel marker| 12x16  | 4x              |
| history pip | 16x16  | 2x              |
| HELD tag    | 33x12  | 4x              |

## Filtering

`project.godot` sets `textures/canvas_textures/default_texture_filter=0`
(Nearest). Godot's default is Linear, which smears pixel art.

The art that is still smooth — the backgrounds, the felts, the roulette wheel,
the slot symbols — carries a per-node `texture_filter = 2` override. Mind the
two enums: at project level Nearest is `0`, but on a node `CanvasItem`
Nearest is `1` and Linear is `2`.
