"""Pixel versions of the table pieces. Native sizes are chosen so that every
place they appear on screen works out to an integer scale."""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixlib import Canvas, from_grid
from pixfont import draw_text

OUT = "/home/user/bowsers-Casino/assets/pixel"

made = []
def save(canvas, name):
    p = canvas.save(os.path.join(OUT, name))
    made.append((name, canvas.w, canvas.h))
    return p


# --- chips, 24x24 -------------------------------------------------------------
CHIPS = [
    ("ChipIvory",  "bone",   "grey",     "slate"),
    ("ChipRed",    "red",    "red_dk",   "ink"),
    ("ChipGreen",  "felt_lt","felt_dk",  "ink"),
    ("ChipPurple", "purple", "purple_dk","ink"),
]
for name, main, edge, deep in CHIPS:
    c = Canvas(24, 24)
    c.disc(11.5, 11.5, 11.4, deep)
    c.disc(11.5, 11.5, 10.4, edge)
    # four crisp rim notches read better at this size than six round ones
    c.rect(10, 1, 4, 3, "white");  c.rect(10, 20, 4, 3, "white")
    c.rect(1, 10, 3, 4, "white");  c.rect(20, 10, 3, 4, "white")
    c.disc(11.5, 11.5, 7.6, main)
    c.ring(11.5, 11.5, 7.6, deep)
    # a four-point star, the same motif as the wheel marker
    c.grid(8, 8, """
...#...
..###..
.#####.
#######
.#####.
..###..
...#...
""".replace("#######", "#######"), {"#": "gold"})
    c.grid(8, 8, """
...#...
..##...
.###...
##.....
.......
.......
.......
""", {"#": "gold_lt"})
    c.set(14, 14, "gold_dk"); c.set(13, 15, "gold_dk"); c.set(15, 13, "gold_dk")
    # rim light, top-left
    c.set(7, 6, "white"); c.set(6, 7, "white"); c.set(8, 5, "white")
    save(c, f"chips/{name}.png")


# --- roulette ball, 12x12 ------------------------------------------------------
c = Canvas(12, 12)
c.disc(5.5, 5.5, 5.4, "steel_dk")
c.disc(5.5, 5.5, 4.4, "steel")
c.disc(4.5, 4.5, 2.4, "steel_lt")
c.set(4, 3, "white"); c.set(3, 4, "white"); c.set(4, 4, "white")
c.set(8, 8, "ink")
save(c, "RouletteBall.png")


# --- plinko peg, 10x10 ----------------------------------------------------------
c = Canvas(10, 10)
c.disc(4.5, 4.5, 4.4, "gold_sh")
c.disc(4.5, 4.5, 3.4, "gold")
c.disc(3.5, 3.5, 1.6, "gold_lt")
c.set(3, 3, "white")
save(c, "Peg.png")


# --- wheel marker, 12x16 (a spike pointing down at the rim) ----------------------
c = from_grid("""
...####...
..######..
..######..
..######..
..######..
...####...
...####...
...####...
....##....
....##....
....##....
.....#....
""", {"#": "gold"})
marker = Canvas(12, 16)
marker.stamp(1, 1, c, 1)
# shade the right side and outline it
for y in range(marker.h):
    for x in range(marker.w):
        if marker.px[y][x] is None:
            if any(0 <= y + dy < marker.h and 0 <= x + dx < marker.w
                   and marker.px[y + dy][x + dx] == "gold"
                   for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                marker.set(x, y, "ink")
for y in range(1, 13):
    for x in range(6, 12):
        if marker.px[y][x] == "gold":
            marker.set(x, y, "gold_dk")
for y in range(1, 7):
    marker.set(4, y, "gold_lt")
save(marker, "WheelMarker.png")


# --- history pip, 16x16 (drawn pale so modulate can tint it) ---------------------
c = Canvas(16, 16)
c.disc(7.5, 7.5, 7.4, "bone")
c.disc(7.5, 7.5, 6.4, "white")
c.disc(5.5, 5.5, 2.0, "white")
c.ring(7.5, 7.5, 7.4, "grey")
save(c, "HistoryPip.png")


# --- dice, 20x20, six faces ------------------------------------------------------
PIP_CELLS = {
    1: [(1, 1)],
    2: [(0, 0), (2, 2)],
    3: [(0, 0), (1, 1), (2, 2)],
    4: [(0, 0), (2, 0), (0, 2), (2, 2)],
    5: [(0, 0), (2, 0), (1, 1), (0, 2), (2, 2)],
    6: [(0, 0), (2, 0), (0, 1), (2, 1), (0, 2), (2, 2)],
}
for value, cells in PIP_CELLS.items():
    c = Canvas(20, 20)
    c.rect(1, 0, 18, 20, "ink"); c.rect(0, 1, 20, 18, "ink")
    c.rect(2, 1, 16, 18, "steel_dk"); c.rect(1, 2, 18, 16, "steel_dk")
    c.rect(2, 2, 16, 16, "steel")
    c.rect(3, 2, 14, 1, "steel_lt"); c.rect(2, 3, 1, 13, "steel_lt")
    c.rect(3, 17, 14, 1, "steel_dk"); c.rect(17, 3, 1, 14, "steel_dk")
    for col, row in cells:
        px, py = 3 + col * 6, 3 + row * 6
        c.grid(px, py, """
.##.
####
####
.##.
""", {"#": "gold"})
        c.set(px + 1, py, "gold_lt"); c.set(px, py + 1, "gold_lt")
        c.set(px + 2, py + 3, "gold_dk"); c.set(px + 3, py + 2, "gold_dk")
    save(c, f"dice/Die{value}.png")


# --- HELD tag, 33x12 --------------------------------------------------------------
c = Canvas(33, 12)
c.rect(1, 0, 31, 12, "ink"); c.rect(0, 1, 33, 10, "ink")
c.rect(2, 1, 29, 10, "gold_dk"); c.rect(1, 2, 31, 8, "gold_dk")
c.rect(2, 2, 29, 7, "gold")
c.rect(3, 2, 27, 1, "gold_lt")
draw_text(c, 5, 4, "HELD", "gold_sh")
save(c, "HeldMarker.png")

print(f"{len(made)} pixel pieces written to assets/pixel/")
for name, w, h in made:
    print(f"  {name:<28} {w}x{h}")
