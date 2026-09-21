"""The house boss: an original character, four expressions, 48x44.

Deliberately not a redraw of Bowser -- a horned saurian croupier in a
dealer's visor, bow tie and waistcoat. Owning the art is the point of the
exercise, which a copy would defeat.
"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixlib import Canvas

OUT = "/home/user/bowsers-Casino/assets/pixel/boss"
W, H = 48, 44


def horn(c, x_tip, y_tip, x_base, y_base, base_w):
    steps = max(abs(y_base - y_tip), 1)
    for i in range(steps + 1):
        t = i / steps
        x = round(x_tip + (x_base - x_tip) * t)
        y = round(y_tip + (y_base - y_tip) * t)
        w = max(1, round(1 + (base_w - 1) * t))
        for dx in range(-(w // 2), w - w // 2):
            c.set(x + dx, y, "horn" if dx < 0 else "horn_dk")


def base(c):
    # horns, curving up and outward from the temples
    horn(c, 11, 0, 16, 9, 5)
    horn(c, 36, 0, 31, 9, 5)

    # head
    c.rect(13, 7, 22, 23, "skin")
    c.disc(15.5, 9.5, 2.6, "skin");  c.disc(32.5, 9.5, 2.6, "skin")
    c.disc(15.5, 27.5, 2.6, "skin"); c.disc(32.5, 27.5, 2.6, "skin")
    c.rect(12, 10, 24, 17, "skin")
    c.rect(13, 8, 5, 18, "skin_lt")          # light from the left
    c.rect(31, 12, 4, 15, "skin_dk")

    # dealer's visor: a brim across the forehead, above the eyes
    c.rect(10, 11, 28, 2, "green_dk")
    c.rect(11, 13, 26, 3, "green")
    c.rect(12, 13, 24, 1, "green_lt")
    c.rect(11, 16, 26, 1, "green_dk")

    # snout, sitting proud of the lower face
    c.rect(16, 22, 16, 9, "belly")
    c.rect(17, 21, 14, 1, "belly")
    c.rect(17, 29, 14, 2, "belly_lt")
    c.set(20, 23, "skin_dk"); c.set(21, 23, "skin_dk")   # nostrils
    c.set(27, 23, "skin_dk"); c.set(28, 23, "skin_dk")

    # neck, shirt, bow tie
    c.rect(19, 31, 10, 2, "skin_dk")
    c.rect(14, 33, 20, 3, "white")
    c.rect(17, 33, 4, 3, "red_dk"); c.rect(27, 33, 4, 3, "red_dk")
    c.rect(18, 34, 2, 1, "red");    c.rect(28, 34, 2, 1, "red")
    c.rect(21, 33, 6, 4, "red_dk")
    c.rect(22, 34, 4, 2, "red")

    # shoulders, waistcoat, arms
    c.rect(7, 36, 34, 8, "purple_dk")
    c.rect(9, 37, 30, 7, "purple")
    c.rect(10, 38, 3, 6, "purple_dk")
    c.rect(20, 36, 8, 8, "white")
    c.set(24, 39, "gold"); c.set(24, 42, "gold")
    c.rect(7, 38, 3, 6, "skin")
    c.rect(38, 38, 3, 6, "skin")
    c.rect(7, 38, 1, 6, "skin_dk")


def eyes(c, pupil_dy=0, narrowed=False, wide=False):
    for ex in (17, 26):
        w, h = (5, 4) if wide else (5, 3)
        c.rect(ex, 18, w, h, "white")
        c.rect(ex, 18, w, 1, "bone")
        px = ex + 2
        c.rect(px, 19 + pupil_dy, 2, 2, "ink")
        if narrowed:
            c.rect(ex, 18, w, 2, "skin")


def brows(c, angry=False, raised_right=False):
    if angry:
        c.grid(16, 16, """
###.......###
.###.....###.
""".replace("#", "o"), {"o": "ink"})
        c.rect(16, 17, 6, 1, "ink")
        c.rect(26, 17, 6, 1, "ink")
    elif raised_right:
        c.rect(16, 17, 6, 1, "ink")
        c.rect(26, 15, 6, 1, "ink")


MOUTHS = {
    "Default": lambda c: c.rect(19, 26, 10, 1, "ink"),
    "Tie": lambda c: (c.rect(20, 26, 8, 1, "ink"), c.set(19, 27, "ink"),
                      c.set(28, 25, "ink")),
}


def grin(c):
    c.rect(18, 25, 12, 4, "red_dk")
    c.rect(19, 25, 10, 1, "ink")
    for x in range(19, 29, 2):
        c.set(x, 26, "white")
    c.set(27, 26, "gold"); c.set(27, 27, "gold")     # gold tooth
    c.rect(19, 28, 10, 1, "ink")


def snarl(c):
    c.rect(19, 26, 10, 3, "red_dk")
    for x in (19, 21, 23, 25, 27):
        c.set(x, 26, "white")
    for x in (20, 22, 24, 26, 28):
        c.set(x, 28, "white")
    c.rect(19, 25, 10, 1, "ink")


def steam(c):
    for x, y in ((8, 7), (9, 4), (11, 2), (39, 7), (38, 4), (36, 2)):
        c.set(x, y, "white"); c.set(x + 1, y - 1, "bone")


def outline(c):
    filled = [[c.px[y][x] is not None for x in range(c.w)] for y in range(c.h)]
    for y in range(c.h):
        for x in range(c.w):
            if filled[y][x]:
                continue
            if any(0 <= y + dy < c.h and 0 <= x + dx < c.w and filled[y + dy][x + dx]
                   for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                c.set(x, y, "ink")


def make(pose):
    c = Canvas(W, H)
    base(c)
    if pose == "Default":
        eyes(c); MOUTHS["Default"](c)
    elif pose == "Win":
        eyes(c, pupil_dy=-1, narrowed=True); grin(c)
    elif pose == "Lost":
        eyes(c, wide=True); brows(c, angry=True); snarl(c); steam(c)
    elif pose == "Tie":
        eyes(c, pupil_dy=1); brows(c, raised_right=True); MOUTHS["Tie"](c)
    outline(c)
    return c


for pose in ("Default", "Win", "Lost", "Tie"):
    make(pose).save(os.path.join(OUT, f"Boss{pose}.png"))
print(f"4 boss poses written to assets/pixel/boss/ at {W}x{H}")
