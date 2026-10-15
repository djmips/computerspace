"""Measure timing and render frames from simulation dumps.

  python render.py core out/core_dump.txt out/core     # GHDL core dump
  python render.py vga  out/vga_dump.txt  out/vga      # DE1 VGA pin dump

core dump: one "hs vs hb vb v3 v2 v1 v0" line per game clock (5.8333 MHz).
vga dump:  one "hs vs r g b" line per output pixel (11.667 MHz), syncs active low.
Writes <prefix>_frameNN.png for a few frames and prints a timing summary.
"""
import collections
import sys

from PIL import Image

GAME_CLK = 23.333333e6 / 4
VGA_PIX = 23.333333e6 / 2


def stats(name, values):
    c = collections.Counter(values)
    common = ", ".join(f"{k} x{n}" for k, n in c.most_common(4))
    print(f"  {name}: {common}")


def split(samples, hs_of, vs_of):
    """Split samples into frames (vsync rising) of lines (hsync rising)."""
    frames, lines, line = [], [], []
    hs_prev = vs_prev = 0
    hs_widths, cur_w = [], 0
    for s in samples:
        hs, vs = hs_of(s), vs_of(s)
        if hs and not hs_prev:
            lines.append(line)
            line = []
        if hs:
            cur_w += 1
        elif hs_prev:
            hs_widths.append(cur_w)
            cur_w = 0
        if vs and not vs_prev:
            frames.append(lines)
            lines = []
        line.append(s)
        hs_prev, vs_prev = hs, vs
    return frames[1:], hs_widths  # first frame is partial



def core(path, prefix):
    samples = []
    with open(path) as f:
        for row in f:
            row = row.strip()
            if len(row) == 8:
                samples.append(tuple(int(ch) for ch in row))
    frames, hs_w = split(samples, lambda s: s[0], lambda s: s[1])
    print(f"core: {len(samples)} game clocks, {len(frames)} whole frames")
    line_lens = [len(l) for fr in frames for l in fr[1:]]
    stats("clocks per line", line_lens)
    stats("hsync width (clocks)", hs_w)
    stats("lines per frame", [len(fr) for fr in frames])
    rises = [i for i in range(1, len(samples)) if samples[i][1] and not samples[i - 1][1]]
    total = (rises[-1] - rises[0]) / (len(rises) - 1)
    print(f"  line rate {GAME_CLK / collections.Counter(line_lens).most_common(1)[0][0] / 1e3:.3f} kHz,"
          f" frame rate {GAME_CLK / total:.3f} Hz")
    for i, fr in enumerate(frames):
        if i % 6 and i != len(frames) - 1:
            continue
        w = max(len(l) for l in fr)
        img = Image.new("RGB", (w, len(fr)), (0, 0, 40))
        px = img.load()
        for y, l in enumerate(fr):
            for x, (hs, vs, hb, vb, v3, v2, v1, v0) in enumerate(l):
                if hs or vs:
                    px[x, y] = (90, 0, 0)
                elif hb or vb:
                    px[x, y] = (0, 0, 40)
                else:
                    lvl = min(255, 120 * v0 + 120 * v1 + 255 * v2)
                    px[x, y] = (lvl, lvl, lvl) if not v3 else (lvl, 0, lvl)
        out = f"{prefix}_frame{i:02d}.png"
        img.resize((w * 2, len(fr) * 2), Image.NEAREST).save(out)
        print("  wrote", out)


def vga(path, prefix):
    samples = []
    with open(path) as f:
        for row in f:
            p = row.split()
            if len(p) == 5:
                samples.append((int(p[0]), int(p[1]), int(p[2], 16), int(p[3], 16), int(p[4], 16)))
    # syncs on the pins are active low
    frames, hs_w = split(samples, lambda s: 1 - s[0], lambda s: 1 - s[1])
    print(f"vga: {len(samples)} pixels, {len(frames)} whole frames")
    line_lens = [len(l) for fr in frames for l in fr[1:]]
    stats("pixels per line", line_lens)
    stats("hsync width (pixels)", hs_w)
    stats("lines per frame", [len(fr) for fr in frames])
    if not frames:
        return
    typical = collections.Counter(line_lens).most_common(1)[0][0]
    rises = [i for i in range(1, len(samples)) if not samples[i][1] and samples[i - 1][1]]
    total = (rises[-1] - rises[0]) / (len(rises) - 1)
    print(f"  hsync {VGA_PIX / typical / 1e3:.3f} kHz ({typical / VGA_PIX * 1e6:.2f} us),"
          f" hsync pulse {collections.Counter(hs_w).most_common(1)[0][0] / VGA_PIX * 1e6:.2f} us,"
          f" vsync {VGA_PIX / total:.3f} Hz")
    # vsync pulse width in lines
    fr = frames[0]
    vs_lines = sum(1 for l in fr if any(s[1] == 0 for s in l))
    print(f"  vsync pulse spans {vs_lines} lines")
    for i, fr in enumerate(frames):
        if i % 6 and i != len(frames) - 1:
            continue
        w = max(len(l) for l in fr)
        img = Image.new("RGB", (w, len(fr)), (0, 0, 0))
        px = img.load()
        for y, l in enumerate(fr):
            for x, (hs, vs, r, g, b) in enumerate(l):
                if not hs or not vs:
                    px[x, y] = (90, 0, 0)
                else:
                    px[x, y] = (r * 17, g * 17, b * 17)
        out = f"{prefix}_frame{i:02d}.png"
        img.save(out)
        print("  wrote", out)


if __name__ == "__main__":
    {"core": core, "vga": vga}[sys.argv[1]](sys.argv[2], sys.argv[3])
