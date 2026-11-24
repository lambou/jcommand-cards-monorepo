"""Packs rendered avatar frames into in-game spritesheets and preview GIFs (plain Python + Pillow).

  python tools/avatars/pack_avatars.py [--frames tools/avatars/frames]

Reads   <frames>/<Name>/<anim>_<NNN>.png   (from render_avatars.py)
Writes  apps/mobile/assets/avatars/<name>_<anim>.png   circular-masked spritesheets (row-major, COLS wide)
        apps/mobile/assets/avatars/meta.json            frame size / counts / fps for the game
        tools/avatars/previews/<name>.gif, all.gif      animation previews (flattened on a dark table colour)
"""
import json, math, os, sys
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(ROOT, "..", ".."))
OUT = os.path.join(REPO, "apps", "mobile", "assets", "avatars")
PREV = os.path.join(ROOT, "previews")
COLS = {"idle": 8, "happy": 6}
FPS = 24
TABLE = (20, 32, 46)


def circle_mask(size):
    s = 4  # supersample for a clean edge
    m = Image.new("L", (size * s, size * s), 0)
    ImageDraw.Draw(m).ellipse((0, 0, size * s - 1, size * s - 1), fill=255)
    return m.resize((size, size), Image.LANCZOS)


def load(frames_dir, name, anim, mask):
    out = []
    i = 0
    while True:
        p = os.path.join(frames_dir, name, "%s_%03d.png" % (anim, i))
        if not os.path.exists(p):
            return out
        im = Image.open(p).convert("RGBA")
        im.putalpha(mask)
        out.append(im)
        i += 1


def sheet(frames, cols):
    w, h = frames[0].size
    rows = math.ceil(len(frames) / cols)
    s = Image.new("RGBA", (w * cols, h * rows), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        s.paste(f, ((i % cols) * w, (i // cols) * h))
    return s


def flat(frame):
    bg = Image.new("RGB", frame.size, TABLE)
    bg.paste(frame, mask=frame.split()[3])
    return bg


def save_gif(frames, path, repeat_idle=1):
    seq = [flat(f) for f in frames] * repeat_idle
    seq[0].save(path, save_all=True, append_images=seq[1:], duration=round(1000 / FPS), loop=0, optimize=False)


def main():
    fd = os.path.join(ROOT, "frames")
    if "--frames" in sys.argv:
        fd = sys.argv[sys.argv.index("--frames") + 1]
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(PREV, exist_ok=True)
    meta = {"fps": FPS, "avatars": {}}
    all_idle = {}
    for name in sorted(d for d in os.listdir(fd) if os.path.isdir(os.path.join(fd, d))):
        first = os.path.join(fd, name, "idle_000.png")
        if not os.path.exists(first):
            continue
        size = Image.open(first).size[0]
        mask = circle_mask(size)
        meta["size"] = size
        seqs = {}
        for anim, cols in COLS.items():
            fr = load(fd, name, anim, mask)
            if not fr:
                continue
            seqs[anim] = fr
            sheet(fr, cols).save(os.path.join(OUT, "%s_%s.png" % (name.lower(), anim)), optimize=True)
            meta["avatars"].setdefault(name.lower(), {})[anim] = {"frames": len(fr), "cols": cols}
        if "idle" in seqs:
            save_gif(seqs["idle"] + seqs.get("happy", []) * 2, os.path.join(PREV, name.lower() + ".gif"))
            all_idle[name] = seqs["idle"]
        print("packed", name, {k: len(v) for k, v in seqs.items()})
    if all_idle:
        n = max(len(v) for v in all_idle.values())
        size = meta["size"]
        strip = []
        for i in range(n):
            im = Image.new("RGB", (size * len(all_idle), size), TABLE)
            for k, frames in enumerate(all_idle.values()):
                f = frames[i % len(frames)]
                im.paste(f, (k * size, 0), f.split()[3])
            strip.append(im)
        strip[0].save(os.path.join(PREV, "all.gif"), save_all=True, append_images=strip[1:], duration=round(1000 / FPS), loop=0)
    json.dump(meta, open(os.path.join(OUT, "meta.json"), "w"), indent=2)


main()
