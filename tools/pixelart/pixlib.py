"""Tiny indexed pixel-art toolkit: one locked palette, ASCII-grid drawing,
and a dependency-free PNG writer."""
import zlib, struct, os

# --- the locked palette ------------------------------------------------------
# Every sprite in the game draws from this and nothing else, which is what
# makes a set of separately-drawn sprites read as one system.
PALETTE = {
    # structure
    "ink":      (0x14, 0x10, 0x1a), "shadow":   (0x2b, 0x22, 0x33),
    "white":    (0xf4, 0xf1, 0xe6), "bone":     (0xd9, 0xd3, 0xc2),
    "grey":     (0x8f, 0x8a, 0x7d), "slate":    (0x4d, 0x4a, 0x45),
    # card faces and suits
    "face":     (0xf6, 0xf3, 0xea), "faceedge": (0xc9, 0xc2, 0xad),
    "red":      (0xd1, 0x34, 0x38), "red_dk":   (0x8e, 0x1f, 0x22),
    "black":    (0x26, 0x22, 0x30), "black_lt": (0x45, 0x40, 0x52),
    # casino gold
    "gold_lt":  (0xff, 0xe0, 0x8a), "gold":     (0xf0, 0xb4, 0x29),
    "gold_dk":  (0xa8, 0x70, 0x0c), "gold_sh":  (0x6b, 0x44, 0x06),
    # felt greens
    "felt_lt":  (0x2f, 0x8f, 0x52), "felt":     (0x1d, 0x6b, 0x3a),
    "felt_dk":  (0x10, 0x43, 0x25),
    # the house boss
    "skin_lt":  (0xf0, 0xa6, 0x3c), "skin":     (0xd1, 0x81, 0x1f),
    "skin_dk":  (0x9a, 0x5a, 0x10), "belly_lt": (0xf5, 0xd7, 0x9a),
    "belly":    (0xe0, 0xbb, 0x72), "horn":     (0xef, 0xe6, 0xcf),
    "horn_dk":  (0xb8, 0xab, 0x8e), "eye":      (0xe8, 0x44, 0x3c),
    "green_lt": (0x56, 0xb0, 0x4a), "green":    (0x2f, 0x7d, 0x34),
    "green_dk": (0x1b, 0x4f, 0x22),
    # accents
    "purple":   (0x5a, 0x3a, 0x8c), "purple_dk":(0x34, 0x20, 0x54),
    "blue":     (0x3b, 0x6f, 0xd4), "teal":     (0x2a, 0xa3, 0x9a),
    "steel_lt": (0x9a, 0xa4, 0xb8), "steel":    (0x5d, 0x66, 0x7a),
    "steel_dk": (0x30, 0x36, 0x45),
}


class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.px = [[None] * w for _ in range(h)]

    def set(self, x, y, key):
        if key is None:
            return
        if 0 <= x < self.w and 0 <= y < self.h:
            assert key in PALETTE, f"colour {key!r} is not in the palette"
            self.px[y][x] = key

    def rect(self, x, y, w, h, key):
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                self.set(xx, yy, key)

    def outline(self, x, y, w, h, key):
        for xx in range(x, x + w):
            self.set(xx, y, key); self.set(xx, y + h - 1, key)
        for yy in range(y, y + h):
            self.set(x, yy, key); self.set(x + w - 1, yy, key)

    def disc(self, cx, cy, r, key):
        for yy in range(int(cy - r), int(cy + r) + 1):
            for xx in range(int(cx - r), int(cx + r) + 1):
                if (xx - cx) ** 2 + (yy - cy) ** 2 <= r * r + 0.2:
                    self.set(xx, yy, key)

    def ring(self, cx, cy, r, key):
        for yy in range(int(cy - r) - 1, int(cy + r) + 2):
            for xx in range(int(cx - r) - 1, int(cx + r) + 2):
                d = (xx - cx) ** 2 + (yy - cy) ** 2
                if (r - 0.8) ** 2 <= d <= (r + 0.4) ** 2:
                    self.set(xx, yy, key)

    def grid(self, x, y, art, legend):
        """Blit an ASCII grid. Characters absent from the legend are skipped,
        so '.' leaves whatever is underneath alone."""
        for dy, row in enumerate(art.strip("\n").split("\n")):
            for dx, ch in enumerate(row):
                if ch in legend:
                    self.set(x + dx, y + dy, legend[ch])

    def stamp(self, x, y, other, scale=1):
        for yy in range(other.h):
            for xx in range(other.w):
                key = other.px[yy][xx]
                if key is None:
                    continue
                for sy in range(scale):
                    for sx in range(scale):
                        self.set(x + xx * scale + sx, y + yy * scale + sy, key)

    def save(self, path):
        raw = bytearray()
        for row in self.px:
            raw.append(0)
            for key in row:
                if key is None:
                    raw += bytes((0, 0, 0, 0))
                else:
                    r, g, b = PALETTE[key]
                    raw += bytes((r, g, b, 255))

        def chunk(t, d):
            return (struct.pack(">I", len(d)) + t + d
                    + struct.pack(">I", zlib.crc32(t + d) & 0xffffffff))

        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "wb") as f:
            f.write(b"\x89PNG\r\n\x1a\n")
            f.write(chunk(b"IHDR", struct.pack(">IIBBBBB", self.w, self.h, 8, 6, 0, 0, 0)))
            f.write(chunk(b"IDAT", zlib.compress(bytes(raw), 9)))
            f.write(chunk(b"IEND", b""))
        return path


def from_grid(art, legend):
    rows = art.strip("\n").split("\n")
    c = Canvas(max(len(r) for r in rows), len(rows))
    c.grid(0, 0, art, legend)
    return c
