"""Renders the 3D avatars to PNG frame sequences (run inside Blender, headless).

  blender -b -P tools/avatars/render_avatars.py -- [--only Rex] [--size 192] [--out tools/avatars/frames]
          [--anim idle,happy] [--still]   # --still renders one frame per avatar (quick look): <out>/_still_<name>.png

Output: <out>/<name>/<anim>_<frame:03d>.png, opaque square (background colour included); pack_avatars.py
masks it to a circle and builds the spritesheets + GIFs. The rig is procedural: head/hair/face live under one
`head` pivot, so any hair kind moves with the head. Loops are seamless (every motion is periodic in the loop length).
"""
import bpy, bmesh, math, json, sys, os
from mathutils import Vector, Matrix

ROOT = os.path.dirname(os.path.abspath(__file__))
ANIMS = {"idle": 64, "happy": 24}  # frames @ 24 fps
HZ = -0.10                          # head centre height (the head sits slightly below the avatar centre)
HR = 0.50                           # head radius; the whole avatar fits a unit circle


def args():
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    o = {"only": None, "size": 192, "out": os.path.join(ROOT, "frames"), "anim": list(ANIMS), "still": False}
    i = 0
    while i < len(a):
        if a[i] == "--only":
            o["only"] = a[i + 1]; i += 2
        elif a[i] == "--size":
            o["size"] = int(a[i + 1]); i += 2
        elif a[i] == "--out":
            o["out"] = a[i + 1]; i += 2
        elif a[i] == "--anim":
            o["anim"] = a[i + 1].split(","); i += 2
        elif a[i] == "--still":
            o["still"] = True; i += 1
        else:
            i += 1
    return o


def lin(c):
    return [(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4) for x in c[:3]]


def material(name, rgb, rough=0.5, emit=False):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*lin(rgb), 1)
    b.inputs["Roughness"].default_value = rough
    if emit:
        b.inputs["Base Color"].default_value = (0, 0, 0, 1)
        b.inputs["Emission Color"].default_value = (*lin(rgb), 1)
        b.inputs["Emission Strength"].default_value = 1.0
    return m


def smooth(o):
    o.data.polygons.foreach_set("use_smooth", [True] * len(o.data.polygons))
    o.data.update()


def link(o, mat, parent=None):
    bpy.context.collection.objects.link(o)
    if mat is not None:
        o.data.materials.append(mat)
    if parent is not None:
        o.parent = parent
        o.matrix_parent_inverse = Matrix.Translation(-parent.location)  # parents are pure translations at rest
    return o


def sphere(name, r, loc, scale=(1, 1, 1), mat=None, parent=None, keep=None):
    """UV sphere. keep(v)->bool trims vertices (a cap/bowl); trimmed shells get a thin solidify."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=48, v_segments=24, radius=r)
    if keep:
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not keep(v.co)], context="VERTS")
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    o.location = loc
    o.scale = scale
    link(o, mat, parent)
    smooth(o)
    if keep:
        md = o.modifiers.new("shell", "SOLIDIFY")
        md.thickness = 0.03
    return o


def cone(name, r, depth, loc, rot, mat, parent):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=32, radius1=r, radius2=0.0, depth=depth)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    o.location = loc
    o.rotation_euler = rot
    link(o, mat, parent)
    smooth(o)
    return o


def empty(name, loc, parent=None):
    e = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(e)
    e.location = loc
    if parent is not None:
        e.parent = parent
        e.matrix_parent_inverse = Matrix.Translation(-parent.location)
    return e


def surf_y(x, z, off=0.0):
    """y on the front of the head sphere at (x, z) so face parts sit on its skin."""
    return -math.sqrt(max(HR * HR - x * x - (z - HZ) ** 2, 0.0)) - off


def above(th):
    """Vertex filter for a cap: keeps what is above local height `th` (the hairline)."""
    return lambda v: v.z > th


def build_hair(kind, st, head):
    hair = material("hair", st["hair"], 0.62)
    acc = material("accent", st["accent"], 0.4)
    if kind == "afro":
        sphere("afro", 0.58, (0, 0.22, HZ + 0.19), mat=hair, parent=head)
        sphere("fringe", HR * 1.05, (0, 0, HZ + 0.03), mat=hair, parent=head, keep=above(0.19))
    elif kind == "bob":
        sphere("bob", 0.60, (0, 0.27, HZ + 0.05), mat=hair, parent=head)
        for s in (-1, 1):
            sphere("lock", 0.24, (s * 0.50, 0.02, HZ - 0.30), (1, 1, 1.25), hair, head)
        sphere("fringe", HR * 1.06, (0, -0.01, HZ + 0.04), mat=hair, parent=head, keep=above(0.19))
    elif kind == "spiky":
        sphere("hair", HR * 1.03, (0, 0.0, HZ + 0.03), mat=hair, parent=head, keep=above(0.19))
        for i in range(5):
            ang = math.radians((i - 2) * 30)  # from straight up, in the x-z plane
            d = Vector((math.sin(ang), 0, math.cos(ang)))
            base = Vector((0, 0, HZ + 0.03)) + d * HR * 0.85
            # cone axis is +Z; rotating about Y by ang points it along d
            cone("spike", 0.16, 0.42, base + d * 0.14, (0, ang, 0), hair, head)
    elif kind == "cap":
        sphere("cap", HR * 1.05, (0, 0, HZ + 0.08), mat=acc, parent=head, keep=above(0.09))
        # visor: back edge buried inside the cap so it grows out of it, tip drooping slightly
        brim = sphere("brim", 0.5, (0, -0.46, HZ + 0.19), (0.52, 0.44, 0.09), material("brim", [c * 0.8 for c in st["accent"]], 0.4), head)
        brim.rotation_euler = (0.18, 0, 0)
        sphere("button", 0.06, (0, 0, HZ + 0.08 + HR * 1.05), mat=material("white", (1, 1, 1), 0.3), parent=head)
        sphere("tuft", 0.20, (0, 0.2, HZ - 0.15), (1.5, 0.8, 0.9), hair, head)  # hair peeking out the back
    else:
        raise SystemExit("unknown hair kind: %s (add it to build_hair)" % kind)


def build(st):
    """Builds one avatar from scratch; returns the handles pose() animates."""
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    skin = material("skin", st["skin"], 0.55)
    dark = material("dark", (0.12, 0.10, 0.12), 0.3)
    white = material("white", (1, 1, 1), 0.2)
    cheek_c = [a * 0.55 + b * 0.45 for a, b in zip(st["skin"], (1.0, 0.45, 0.5))]
    cheek = material("cheek", cheek_c, 0.6)
    pivot = Vector((0, 0, HZ - 0.5))

    bpy.ops.mesh.primitive_plane_add(size=8, location=(0, 2.5, 0), rotation=(math.pi / 2, 0, 0))
    bpy.context.active_object.data.materials.append(material("bg", st["bg"], emit=True))

    body = empty("body", (0, 0.05, -0.95))
    sphere("shoulders", 0.78, (0, 0.05, -0.95), (1.18, 0.6, 0.8), material("shirt", st["shirt"], 0.6), body)

    head = empty("head", pivot)
    sphere("head", HR, (0, 0, HZ), mat=skin, parent=head)
    for s in (-1, 1):
        sphere("ear", 0.095, (s * 0.485, 0.0, HZ + 0.02), (0.6, 0.8, 1.0), skin, head)

    brow_m = material("brow", [c * 0.5 for c in st["hair"]], 0.6)
    eyes = []
    for s in (-1, 1):
        x, z = s * st["gap"], HZ + 0.03
        k = st["eye"]
        y = surf_y(x, z)
        piv = empty("eye", (x, y, z), head)
        sphere("pupil", 0.066 * k, (x, y - 0.006, z), (1, 0.45, 1.25), dark, piv)
        sphere("glint", 0.022 * k, (x + 0.022 * k, y - 0.032, z + 0.034 * k), (1, 0.6, 1), white, piv)
        eyes.append((piv, Vector(piv.location)))
        bz = HZ + 0.14 + 0.05 * (k - 1.0)  # brow: a short dark bar, outer end raised by st["brow"]
        bx = x + s * 0.02
        brow = sphere("brow", 0.07, (bx, surf_y(bx, bz, 0.002), bz), (1.0, 0.22, 0.2), brow_m, head)
        brow.rotation_euler = (0, s * st["brow"], 0)
        cx, cz = s * 0.31, HZ - 0.14
        # blush: a flat disc turned to follow the curved skin and sunk in so only a thin cap shows
        cy = surf_y(cx, cz)
        ck = sphere("cheek", 0.11, (cx, cy + 0.006, cz), (1, 0.1, 0.7), cheek, head)
        ck.rotation_euler = Vector((cx, cy, cz - HZ)).normalized().to_track_quat("-Y", "Z").to_euler()

    # two mouths: a thin smile (idle) and an open grin (happy); pose() swaps them by scale
    mz = HZ - 0.22
    mw = {"smile": 0.12, "smirk": 0.11, "wide": 0.16}[st["mouth"]]
    cu = bpy.data.curves.new("smile", "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = 0.016
    cu.bevel_resolution = 4
    cu.use_fill_caps = True
    sp = cu.splines.new("POLY")
    n = 15
    sp.points.add(n - 1)
    for i in range(n):
        x = -mw + 2 * mw * i / (n - 1)
        u = x / mw
        z = mz - 0.05 * (1 - u * u) + 0.03
        if st["mouth"] == "smirk":
            z += 0.035 * u + 0.012  # one corner higher
        x += 0.02 if st["mouth"] == "smirk" else 0.0
        sp.points[i].co = (x, surf_y(x, z, 0.004), z, 1)
    smile = bpy.data.objects.new("smile", cu)
    link(smile, dark, head)
    grin = sphere("grin", 0.13, (0, surf_y(0, mz + 0.01, 0.002), mz + 0.03), (1.0 + (mw - 0.12) * 4, 0.18, 0.95), dark, head,
                  keep=lambda v: v.z < 0.0)
    tongue = sphere("tongue", 0.07, (0, surf_y(0, mz - 0.03, 0.008), mz - 0.05), (1.0, 0.15, 0.55),
                    material("tongue", (0.95, 0.45, 0.5), 0.5), head, keep=lambda v: v.z < 0.0)

    build_hair(st["kind"], st, head)

    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    bpy.context.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 1.82
    cam.location = (0, -6, 0)
    cam.rotation_euler = (math.pi / 2, 0, 0)
    bpy.context.scene.camera = cam

    target = empty("target", (0, 0, -0.1))
    cam.location = (0, -6, -0.10)
    for name, loc, energy, size in (("key", (-2.2, -3.6, 2.8), 260, 3.0), ("fill", (3.0, -3.2, 0.2), 90, 4.0), ("rim", (1.5, 2.5, 2.5), 120, 2.0)):
        L = bpy.data.objects.new(name, bpy.data.lights.new(name, "AREA"))
        L.data.energy = energy
        L.data.size = size
        L.location = loc
        bpy.context.collection.objects.link(L)
        c = L.constraints.new("TRACK_TO")
        c.target = target
        c.track_axis = "TRACK_NEGATIVE_Z"
        c.up_axis = "UP_Y"
    w = bpy.context.scene.world or bpy.data.worlds.new("w")
    bpy.context.scene.world = w
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.5, 0.5, 0.55, 1)
    w.node_tree.nodes["Background"].inputs[1].default_value = 0.7
    return {"tilt": st["tilt"], "head": head, "body": body, "eyes": eyes, "smile": smile, "grin": grin, "tongue": tongue, "pivot": pivot}


def setv(o, on):
    o.scale = (1, 1, 1) if on else (0.0001, 0.0001, 0.0001)


def pose(h, anim, f, n, idx):
    ph = 2 * math.pi * f / n
    off = idx * 0.9  # per-avatar phase so they never move in lockstep
    head, body = h["head"], h["body"]
    happy = anim == "happy"
    if not happy:
        head.location = h["pivot"] + Vector((0.018 * math.sin(ph + off + 1.0), 0, 0.016 * math.sin(ph + off)))
        head.rotation_euler = (0.03 * math.sin(2 * ph + off), h["tilt"] + 0.035 * math.sin(ph + off + 1.0), 0.13 * math.sin(ph + off + 2.0))
        body.scale = (1 + 0.012 * math.sin(ph + off - 0.6), 1, 1 + 0.03 * math.sin(ph + off - 0.6))
        look = (math.sin(ph + off + 0.5), 0.5 * math.sin(ph + off + 2.2))
        bf = (f - (14 + idx * 11)) % n
        eye_s = 1.0 - math.sin(math.pi * bf / 6.0) * 0.92 if bf < 6 else 1.0  # one blink per loop
    else:
        hop = abs(math.sin(ph))
        head.location = h["pivot"] + Vector((0.02 * math.sin(ph), 0, 0.075 * hop))
        head.rotation_euler = (0.02, h["tilt"] + 0.12 * math.sin(ph), 0.05 * math.sin(ph))
        body.scale = (1 + 0.02 * (1 - hop), 1, 1 - 0.04 * (1 - hop))
        look = (0.0, 0.3)
        eye_s = 0.42  # happy squint
    for piv, base in h["eyes"]:
        piv.location = base + Vector((look[0] * 0.012, 0, look[1] * 0.012))
        piv.scale = (1, 1, max(eye_s, 0.05))
    setv(h["smile"], not happy)
    setv(h["grin"], happy)
    setv(h["tongue"], happy)


def main():
    o = args()
    st_all = json.load(open(os.path.join(ROOT, "styles.json")))["avatars"]
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 32
    sc.cycles.use_denoising = True
    sc.render.resolution_x = sc.render.resolution_y = o["size"]
    sc.render.resolution_percentage = 100
    sc.render.film_transparent = False
    sc.view_settings.view_transform = "Standard"
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGB"
    for idx, st in enumerate(st_all):
        if o["only"] and st["name"].lower() != o["only"].lower():
            continue
        h = build(st)
        if o["still"]:
            pose(h, "idle", 0, ANIMS["idle"], idx)
            sc.render.filepath = os.path.join(o["out"], "_still_%s.png" % st["name"])
            bpy.ops.render.render(write_still=True)
            continue
        for anim in o["anim"]:
            n = ANIMS[anim]
            d = os.path.join(o["out"], st["name"])
            os.makedirs(d, exist_ok=True)
            for f in range(n):
                pose(h, anim, f, n, idx)
                sc.render.filepath = os.path.join(d, "%s_%03d.png" % (anim, f))
                bpy.ops.render.render(write_still=True)
            print("done", st["name"], anim)


main()
