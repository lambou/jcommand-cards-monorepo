"""Pack the crown loop from make_crown.py into one spritesheet + meta.json.

    python tools/blender/pack_crown.py <frames_dir> <out_dir> [frame_px=192] [cols=6]

Reads <frames_dir>/f00.png.. and writes <out_dir>/crown.png and crown.json; the preview GIF goes to tools/previews/ (lab output, never into assets).
Regenerate with:
  blender -b -P tools/blender/make_crown.py -- <abs scratch dir> --frames 24 --size 384
then run this with <frames_dir> = <scratch dir>/frames and <out_dir> = apps/mobile/assets/crown. Needs Pillow.
"""
import json, os, sys
from PIL import Image

frames_dir, out_dir = sys.argv[1], sys.argv[2]
px = int(sys.argv[3]) if len(sys.argv) > 3 else 192
cols = int(sys.argv[4]) if len(sys.argv) > 4 else 6
os.makedirs(out_dir, exist_ok=True)
preview_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "previews"); os.makedirs(preview_dir, exist_ok=True)
files = sorted(f for f in os.listdir(frames_dir) if f.endswith(".png"))
rows = -(-len(files) // cols)
sheet = Image.new("RGBA", (cols * px, rows * px), (0, 0, 0, 0))
gif = []
for i, n in enumerate(files):
    im = Image.open(os.path.join(frames_dir, n)).convert("RGBA").resize((px, px), Image.LANCZOS)
    sheet.paste(im, ((i % cols) * px, (i // cols) * px))
    bg = Image.new("RGBA", im.size, (18, 84, 54, 255)); bg.alpha_composite(im)
    gif.append(bg.convert("P", palette=Image.ADAPTIVE))
sheet.save(os.path.join(out_dir, "crown.png"), optimize=True)
gif[0].save(os.path.join(preview_dir, "crown.gif"), save_all=True, append_images=gif[1:], duration=1000 // 24, loop=0, disposal=2)
json.dump({"fps": 24, "frame_px": px, "cols": cols, "rows": rows, "frames": len(files)}, open(os.path.join(out_dir, "crown.json"), "w"), indent=2)
print("crown.png", len(files), "frames", os.path.getsize(os.path.join(out_dir, "crown.png")) // 1024, "KB")
