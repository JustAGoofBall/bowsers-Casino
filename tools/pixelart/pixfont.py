"""A 3x5 pixel font and the four suit pips, shared by the cards and the UI tags."""

FONT = {
    "0": ["###", "#.#", "#.#", "#.#", "###"],
    "1": [".#.", "##.", ".#.", ".#.", "###"],
    "2": ["###", "..#", "###", "#..", "###"],
    "3": ["###", "..#", "###", "..#", "###"],
    "4": ["#.#", "#.#", "###", "..#", "..#"],
    "5": ["###", "#..", "###", "..#", "###"],
    "6": ["###", "#..", "###", "#.#", "###"],
    "7": ["###", "..#", "..#", "..#", "..#"],
    "8": ["###", "#.#", "###", "#.#", "###"],
    "9": ["###", "#.#", "###", "..#", "###"],
    "A": ["###", "#.#", "###", "#.#", "#.#"],
    "J": ["..#", "..#", "..#", "#.#", "###"],
    "Q": ["###", "#.#", "#.#", "###", "..#"],
    "K": ["#.#", "#.#", "##.", "#.#", "#.#"],
    "H": ["#.#", "#.#", "###", "#.#", "#.#"],
    "E": ["###", "#..", "###", "#..", "###"],
    "L": ["#..", "#..", "#..", "#..", "###"],
    "D": ["##.", "#.#", "#.#", "#.#", "##."],
}

PIPS = {
    "H": [".##.##.", "#######", "#######", "#######", ".#####.", "..###..", "...#..."],
    "D": ["...#...", "..###..", ".#####.", "#######", ".#####.", "..###..", "...#..."],
    "S": ["...#...", "..###..", ".#####.", "#######", "#######", "...#...", ".#####."],
    "C": ["..###..", ".#####.", "..###..", "##.#.##", "#######", "...#...", ".#####."],
}

SUIT_COLOUR = {"H": "red", "D": "red", "S": "black", "C": "black"}
SUIT_SHADE = {"H": "red_dk", "D": "red_dk", "S": "black_lt", "C": "black_lt"}


def text_width(s):
    return sum(4 if ch != " " else 2 for ch in s) - 1


def draw_text(canvas, x, y, s, colour):
    cx = x
    for ch in s:
        if ch == " ":
            cx += 2
            continue
        rows = FONT[ch]
        for dy, row in enumerate(rows):
            for dx, c in enumerate(row):
                if c == "#":
                    canvas.set(cx + dx, y + dy, colour)
        cx += 4
    return cx - x - 1


def draw_pip(canvas, x, y, suit, colour, scale=1):
    for dy, row in enumerate(PIPS[suit]):
        for dx, c in enumerate(row):
            if c != "#":
                continue
            for sy in range(scale):
                for sx in range(scale):
                    canvas.set(x + dx * scale + sx, y + dy * scale + sy, colour)
