"""The 53-card pixel deck, 32x44 each.

Every card the existing code can ask for is generated: the filenames are
<suit><rank>.png over H/D/C/S and A,2..10,J,Q,K, plus CardBack.png.
"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixlib import Canvas
from pixfont import draw_text, draw_pip, text_width, SUIT_COLOUR, SUIT_SHADE

OUT = "/home/user/bowsers-Casino/assets/pixel/cards"
W, H = 32, 44
SUITS = ["H", "D", "C", "S"]
RANKS = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]

# 16x16 court busts. o=outline, s=skin, e=eye, m=mouth, r=robe, g=gold, w=white
COURT = {
    "K": [
        "...g.g.g.g.g....",
        "...gggggggggg...",
        "...oooooooooo...",
        "...osssssssso...",
        "...ossessesso...",
        "...osssssssso...",
        "...ossmmmmsso...",
        "....oossssoo....",
        "..oorrrrrrrroo..",
        ".orrrrggggrrrro.",
        ".orrrrggggrrrro.",
        ".orrrrrrrrrrrro.",
        "..oooooooooooo..",
        "................",
        "................",
        "................",
    ],
    "Q": [
        ".....g.g.g......",
        "...gggggggggg...",
        "...oooooooooo...",
        "...osssssssso...",
        "...ossessesso...",
        "...osssssssso...",
        "...ossmmmmsso...",
        "....oossssoo....",
        "..oowrrrrrrwoo..",
        ".owrrrrggggrrwo.",
        ".owrrrrggggrrwo.",
        ".owrrrrrrrrrrwo.",
        "..oooooooooooo..",
        "................",
        "................",
        "................",
    ],
    "J": [
        "....gggggggg....",
        "...gwwwwwwwwg...",
        "...oooooooooo...",
        "...osssssssso...",
        "...ossessesso...",
        "...osssssssso...",
        "...ossmmmmsso...",
        "....oossssoo....",
        "...oorrrrrroo...",
        "..orrrrggrrrro..",
        "..orrrrggrrrro..",
        "..orrrrrrrrrro..",
        "...oooooooooo...",
        "................",
        "................",
        "................",
    ],
}


def frame(suit):
    c = Canvas(W, H)
    # rounded rectangle: an ink shell with the face inset by one pixel
    c.rect(2, 0, W - 4, H, "ink"); c.rect(0, 2, W, H - 4, "ink")
    c.rect(1, 1, W - 2, H - 2, "ink")
    c.rect(3, 1, W - 6, H - 2, "face"); c.rect(1, 3, W - 2, H - 6, "face")
    c.rect(2, 2, W - 4, H - 4, "face")
    # a faint inner rule in the suit's colour so the two colours read apart
    tint = SUIT_SHADE[suit]
    for x in range(4, W - 4):
        c.set(x, 2, "faceedge")
    for y in range(4, H - 4):
        c.set(2, y, "faceedge")
    c.set(3, 3, tint); c.set(W - 4, H - 4, tint)
    return c


def corner(c, rank, suit, colour, flip):
    label = rank
    tw = text_width(label)
    if flip:
        draw_text(c, W - 3 - tw, H - 9, label, colour)
    else:
        draw_text(c, 3, 3, label, colour)
        draw_pip(c, 3, 9, suit, colour)


def make_card(suit, rank):
    colour = SUIT_COLOUR[suit]
    c = frame(suit)
    corner(c, rank, suit, colour, False)
    corner(c, rank, suit, colour, True)

    if rank in COURT:
        legend = {
            "o": SUIT_SHADE[suit], "s": "belly_lt", "e": "ink", "m": "red_dk",
            "r": colour, "g": "gold", "w": "white",
        }
        art = "\n".join(COURT[rank])
        c.grid(8, 15, art, legend)
    else:
        # one big centre pip; the corner index carries the rank
        draw_pip(c, 9, 16, suit, colour, scale=2)
        if rank == "A":
            # an ace gets a gold ring so it reads apart from the spot cards
            c.ring(15.5, 22.5, 9.5, "gold")
            c.set(6, 22, "gold_lt"); c.set(25, 23, "gold_dk")
    return c


def make_back():
    c = Canvas(W, H)
    c.rect(2, 0, W - 4, H, "ink"); c.rect(0, 2, W, H - 4, "ink")
    c.rect(1, 1, W - 2, H - 2, "ink")
    c.rect(3, 1, W - 6, H - 2, "red_dk"); c.rect(1, 3, W - 2, H - 6, "red_dk")
    c.rect(2, 2, W - 4, H - 4, "red_dk")
    c.rect(4, 4, W - 8, H - 8, "red")
    # gold lattice
    for y in range(4, H - 4):
        for x in range(4, W - 4):
            if (x + y) % 6 == 0 or (x - y) % 6 == 0:
                c.set(x, y, "gold_dk")
    c.outline(4, 4, W - 8, H - 8, "gold")
    # centre medallion, matching the chip emblem
    c.disc(15.5, 21.5, 6.4, "ink")
    c.disc(15.5, 21.5, 5.4, "gold_dk")
    c.grid(12, 18, """
...#...
..###..
.#####.
#######
.#####.
..###..
...#...
""", {"#": "gold"})
    c.set(15, 19, "gold_lt"); c.set(14, 20, "gold_lt")
    return c


for court_rank, rows in COURT.items():
    assert len(rows) == 16, (court_rank, len(rows))
    for i, row in enumerate(rows):
        assert len(row) == 16, (court_rank, i, len(row), row)
        assert all(ch in ".osemrgw" for ch in row), (court_rank, i, row)

count = 0
for suit in SUITS:
    for rank in RANKS:
        make_card(suit, rank).save(os.path.join(OUT, f"{suit}{rank}.png"))
        count += 1
make_back().save(os.path.join(OUT, "CardBack.png"))
count += 1
print(f"{count} card sprites written to assets/pixel/cards/ at {W}x{H}")
