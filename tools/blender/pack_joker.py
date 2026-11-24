"""Pack the roar frames from make_joker.py into one spritesheet per mane colour, plus a preview GIF.

    python tools/blender/pack_joker.py <frames_dir> <out_dir> [frame_px=256] [cols=6]

Reads <frames_dir>/<color>/f00.png.. (roar) and <frames_dir>/<color>_idle/f00.png.. (idle loop) and writes
<out_dir>/joker_<color>_roar.png / joker_<color>_idle.png, matching .gif previews and <out_dir>/meta.json. Frames are rendered bigger and downsampled here for clean edges. Needs Pillow.
"""
import json
import os
import sys

from PIL import Image

COLORS = ["red", "black"]
FPS = 24


def main():
    if len(sys.argv) < 3:
        raise SystemExit(__doc__)
    frames_dir, out_dir = sys.argv[1], sys.argv[2]
    px = int(sys.argv[3]) if len(sys.argv) > 3 else 256
    cols = int(sys.argv[4]) if len(sys.argv) > 4 else 6
    os.makedirs(out_dir, exist_ok=True)
    meta = {"fps": FPS, "frame_px": px, "cols": cols, "sheets": {}, "idle": {}}
    for color, anim in [(c, a) for c in COLORS for a in ("roar", "idle")]:
        d = os.path.join(frames_dir, color if anim == "roar" else color + "_idle")
        if not os.path.isdir(d):
            continue
        files = sorted(f for f in os.listdir(d) if f.endswith(".png"))
        rows = -(-len(files) // cols)
        sheet = Image.new("RGBA", (cols * px, rows * px), (0, 0, 0, 0))
        frames = []
        for i, name in enumerate(files):
            im = Image.open(os.path.join(d, name)).convert("RGBA").resize((px, px), Image.LANCZOS)
            sheet.paste(im, ((i % cols) * px, (i // cols) * px))
            frames.append(im)
        sheet_path = os.path.join(out_dir, f"joker_{color}_{anim}.png")
        sheet.save(sheet_path, optimize=True)
        # preview GIF on a card-like background so the silhouette is judged against something real
        bg = (250, 247, 240, 255)
        gif = []
        for im in frames:
            f = Image.new("RGBA", im.size, bg)
            f.alpha_composite(im)
            gif.append(f.convert("P", palette=Image.ADAPTIVE))
        gif[0].save(os.path.join(out_dir, f"joker_{color}_{anim}.gif"), save_all=True, append_images=gif[1:],
                    duration=int(1000 / FPS), loop=0, disposal=2)
        entry = {"file": f"joker_{color}_{anim}.png", "frames": len(files), "rows": rows}
        if anim == "roar":
            meta["sheets"][color] = entry
        else:
            meta["idle"][color] = entry
        print(f"{sheet_path}: {len(files)} frames, {cols}x{rows} @ {px}px, {os.path.getsize(sheet_path) // 1024} KB")
    with open(os.path.join(out_dir, "meta.json"), "w") as fh:
        json.dump(meta, fh, indent=2)


main()
