"""Copy ../rtl into build/src with the small patches GHDL needs.

rtl/ stays exactly as upstream (Quartus accepts it). GHDL rejects:
  * sync_star_board: `slv = "0101"` is ambiguous with both
    std_logic_1164 and std_logic_unsigned visible -> compare integers.
  * motion_board: a single-element association `Q(11) => x` on an out port
    -> add `open` for the remaining bits.
"""
import pathlib
import re
import sys

here = pathlib.Path(__file__).resolve().parent
src = here.parent / "rtl"
dst = here / "build" / "src"
dst.mkdir(parents=True, exist_ok=True)

for f in src.glob("*.vhd"):
    text = f.read_text(encoding="latin-1")
    if f.name == "sync_star_board.vhd":
        text, n = re.subn(r'when g3_in = "([01]{4})"',
                          lambda m: f"when conv_integer(g3_in) = {int(m.group(1), 2)}",
                          text)
        assert n >= 10, n
    if f.name == "motion_board.vhd":
        for bit in (11, 9):
            old = f"Q({bit}) => "
            assert old in text
            text = re.sub(rf"Q\({bit}\) => (\w+)",
                          rf"Q(15 downto {bit + 1}) => open, Q({bit}) => \1, Q({bit - 1} downto 0) => open",
                          text)
    (dst / f.name).write_text(text, encoding="latin-1")

print("prepared", dst)
