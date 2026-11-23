"""Pack the frames from make_suits.py into one spritesheet per suit.

    python tools/blender/pack_suits.py <frames_dir> <out_dir> [frame_px=256] [cols=6]

Writes <out_dir>/suit_H.png etc. Needs Pillow.
"""
import os
import sys

from PIL import Image

SUITS = ["H", "D", "C", "S"]


def main():
    if len(sys.argv) < 3:
        raise SystemExit(__doc__)
    frames_dir, out_dir = sys.argv[1], sys.argv[2]
    px = int(sys.argv[3]) if len(sys.argv) > 3 else 256
    cols = int(sys.argv[4]) if len(sys.argv) > 4 else 6
    os.makedirs(out_dir, exist_ok=True)
    for suit in SUITS:
        d = os.path.join(frames_dir, suit)
        if not os.path.isdir(d):
            continue
        files = sorted(f for f in os.listdir(d) if f.endswith(".png"))
        rows = -(-len(files) // cols)
        sheet = Image.new("RGBA", (cols * px, rows * px), (0, 0, 0, 0))
        for i, name in enumerate(files):
            im = Image.open(os.path.join(d, name)).convert("RGBA")
            im = im.resize((px, px), Image.LANCZOS)
            sheet.paste(im, ((i % cols) * px, (i // cols) * px))
        out = os.path.join(out_dir, f"suit_{suit}.png")
        sheet.save(out, optimize=True)
        print(f"{out}: {len(files)} frames, {cols}x{rows} @ {px}px")


main()
