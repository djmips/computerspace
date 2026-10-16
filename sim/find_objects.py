"""Locate the objects (video bit 2: rocket, saucers, missiles) in a core dump.

  python find_objects.py out/fire_dump.txt

Splits the dump into frames (vsync rising) and lines (hsync rising), finds
connected groups of video[2] pixels per frame, and prints each group's
bounding box (x = game clocks from hsync, y = line in frame) and size.
"""
import sys


def frames_of(path):
    frames, lines, line = [], [], []
    hs_prev = vs_prev = 0
    for raw in open(path):
        s = raw.strip()
        if len(s) != 8:
            continue
        hs, vs, v2 = s[0] == "1", s[1] == "1", s[5] == "1"
        if hs and not hs_prev:
            lines.append(line)
            line = []
        if vs and not vs_prev and lines:
            frames.append(lines)
            lines = []
        line.append(v2)
        hs_prev, vs_prev = hs, vs
    return frames


def groups(lines):
    pts = {(x, y) for y, l in enumerate(lines) for x, v in enumerate(l) if v}
    out = []
    while pts:
        stack = [pts.pop()]
        g = []
        while stack:
            x, y = stack.pop()
            g.append((x, y))
            for dx in (-2, -1, 0, 1, 2):
                for dy in (-2, -1, 0, 1, 2):
                    p = (x + dx, y + dy)
                    if p in pts:
                        pts.remove(p)
                        stack.append(p)
        xs, ys = [p[0] for p in g], [p[1] for p in g]
        out.append((min(xs), max(xs), min(ys), max(ys), len(g)))
    return sorted(out, key=lambda b: (b[2], b[0]))


if __name__ == "__main__":
    for n, f in enumerate(frames_of(sys.argv[1])):
        print(f"frame {n}: {len(f)} lines")
        for x0, x1, y0, y1, size in groups(f):
            print(f"   x {x0:3d}-{x1:3d}  y {y0:3d}-{y1:3d}  {size:3d} px")
