"""Render the four card suits as 3D turntable frames (Blender script).

Run (Blender 4.2+ / 5.x, headless):

    blender -b -P tools/blender/make_suits.py -- --out <frames_dir>

For each suit this writes <frames_dir>/<S>/f00.png .. f23.png: a transparent,
orthographic, full 360-degree spin (frame 0 = facing the camera, so it doubles
as the still icon). `pack_suits.py` then packs them into one spritesheet per suit
for the Godot client.

The shapes mirror apps/mobile/scripts/ui/card_art.gd (same proportions), but
built as extruded + bevelled curves with a glossy material.
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

FRAMES = 96
RENDER_PX = 384          # rendered big, downsampled to 256 by pack_suits.py (anti-aliasing)
SAMPLES = 64
ENGINE = os.environ.get("SUIT_ENGINE", "EEVEE")   # or CYCLES (slower, more accurate)
SUITS = ["H", "D", "C", "S"]

# Linear-space base colours = the flat card art colours in card_art.gd (RED / BLACK), so the 3D suits
# read as the same red and ink as the cards they sit next to.
RED = (0.6038, 0.0085, 0.0134, 1.0)
BLACK = (0.0100, 0.0100, 0.0174, 1.0)


# --------------------------------------------------------------- 2D outlines
# All outlines are lists of (x, y) with y UP, roughly spanning [-1, 1].

def circle(cx, cy, r, n=48):
    return [(cx + r * math.cos(2 * math.pi * i / n), cy + r * math.sin(2 * math.pi * i / n)) for i in range(n)]


def heart_points(n=120):
    pts = []
    for i in range(n):
        t = 2 * math.pi * i / n
        x = 16 * math.sin(t) ** 3
        y = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
        pts.append((x / 17.0, (y + 2.5) / 17.0))   # centre vertically-ish
    return pts


def stem_points(top_y, bottom_y, top_w=0.09, bottom_w=0.30):
    """A flared stem with a gently curved base (spade / club)."""
    steps = 8

    def wall(i):
        f = i / steps
        return top_y + (bottom_y - top_y) * f, top_w + (bottom_w - top_w) * (f ** 2.2)

    pts = []
    for i in range(steps + 1):          # right wall, top -> bottom
        y, w = wall(i)
        pts.append((w, y))
    for i in range(steps, -1, -1):      # left wall, bottom -> top
        y, w = wall(i)
        pts.append((-w, y))
    return pts


def suit_shapes(suit):
    """Return a list of closed outlines that together make the suit."""
    if suit == "D":
        return [[(0.0, 1.0), (0.66, 0.0), (0.0, -1.0), (-0.66, 0.0)]]
    if suit == "H":
        return [[(x, y) for x, y in heart_points()]]
    if suit == "S":
        body = [(x, -y) for x, y in heart_points()]
        return [body, stem_points(-0.25, -0.98)]
    if suit == "C":
        return [
            circle(0.0, 0.46, 0.34),
            circle(-0.42, -0.08, 0.34),
            circle(0.42, -0.08, 0.34),
            circle(0.0, 0.05, 0.30),
            stem_points(-0.1, -0.98),
        ]
    raise ValueError(suit)


# --------------------------------------------------------------- scene helpers

def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    return bpy.context.scene


def make_material(suit):
    red = suit in ("H", "D")
    mat = bpy.data.materials.new(f"suit_{suit}")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = RED if red else BLACK
    bsdf.inputs["Roughness"].default_value = 0.38 if red else 0.30
    bsdf.inputs["Metallic"].default_value = 0.0
    for name, val in (("Coat Weight", 0.35), ("Coat Roughness", 0.15), ("Clearcoat", 0.35), ("Clearcoat Roughness", 0.15)):
        if name in bsdf.inputs:
            bsdf.inputs[name].default_value = val
    if "Specular IOR Level" in bsdf.inputs:
        bsdf.inputs["Specular IOR Level"].default_value = 0.35
    return mat


def _seg_dist(px, py, ax, ay, bx, by):
    dx, dy = bx - ax, by - ay
    L = dx * dx + dy * dy
    t = 0.0 if L == 0 else max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / L))
    cx, cy = ax + t * dx, ay + t * dy
    return math.hypot(px - cx, py - cy)


def _dist_to_outline(px, py, outline):
    n = len(outline)
    return min(_seg_dist(px, py, *outline[i], *outline[(i + 1) % n]) for i in range(n))


def _inside(px, py, outline):
    c = False
    n = len(outline)
    for i in range(n):
        x1, y1 = outline[i]
        x2, y2 = outline[(i + 1) % n]
        if (y1 > py) != (y2 > py) and px < (x2 - x1) * (py - y1) / (y2 - y1) + x1:
            c = not c
    return c


MAX_R = 0.55      # how far from the rim the dome takes to reach full height
MAX_T = 0.42      # half-thickness of the pillow


def make_shape_object(name, outline, mat):
    """Inflate a 2D outline into a plump, rounded 'pillow' (domed like an apple, no flat sides).

    Triangulate the outline with interior points (constrained Delaunay), lift each vertex by a
    circular profile of its distance to the rim, then mirror to the back.
    """
    from mathutils import geometry
    xs = [p[0] for p in outline]
    ys = [p[1] for p in outline]
    step = 0.045
    verts = [Vector((x, y)) for x, y in outline]
    n = len(outline)
    edges = [(i, (i + 1) % n) for i in range(n)]
    gx = min(xs) + step / 2
    while gx < max(xs):
        gy = min(ys) + step / 2
        while gy < max(ys):
            if _inside(gx, gy, outline) and _dist_to_outline(gx, gy, outline) > step * 0.6:
                verts.append(Vector((gx, gy)))
            gy += step
        gx += step
    res = geometry.delaunay_2d_cdt(verts, edges, [list(range(n))], 1, 1e-6)
    co, faces = res[0], res[2]

    dist = [_dist_to_outline(v.x, v.y, outline) for v in co]
    R = min(MAX_R, max(dist))
    T = min(MAX_T, R * 0.85)

    def height(d):
        s = min(d / R, 1.0)
        return T * math.sqrt(max(0.0, 1.0 - (1.0 - s) ** 2))

    bm = bmesh.new()
    front = [bm.verts.new((v.x, v.y, height(d))) for v, d in zip(co, dist)]
    back = [bm.verts.new((v.x, v.y, -height(d))) for v, d in zip(co, dist)]
    for f in faces:
        bm.faces.new([front[i] for i in f])
        bm.faces.new([back[i] for i in reversed(f)])
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)   # weld the two halves along the rim
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    mesh.shade_smooth()
    ob = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(ob)
    ob.data.materials.append(mat)
    return ob


def build_suit(suit):
    """Build the suit standing upright (in the XZ plane, facing -Y) under a pivot empty."""
    mat = make_material(suit)
    pivot = bpy.data.objects.new(f"pivot_{suit}", None)
    bpy.context.scene.collection.objects.link(pivot)
    for i, outline in enumerate(suit_shapes(suit)):
        ob = make_shape_object(f"{suit}_{i}", outline, mat)
        ob.rotation_euler = (math.radians(90), 0.0, 0.0)   # XY plane -> XZ plane
        ob.parent = pivot
    return pivot


def look_at(obj, target):
    direction = Vector(target) - obj.location
    obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def add_area_light(name, loc, size, energy, color=(1, 1, 1)):
    ld = bpy.data.lights.new(name, "AREA")
    ld.energy = energy
    ld.size = size
    ld.color = color
    lo = bpy.data.objects.new(name, ld)
    lo.location = loc
    bpy.context.scene.collection.objects.link(lo)
    look_at(lo, (0, 0, 0))
    return lo


def setup_world(scene, strength=0.8):
    """Vertical gradient sky so the glossy surface has something to reflect."""
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    scene.world = world
    nt = world.node_tree
    nt.nodes.clear()
    coord = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    bg = nt.nodes.new("ShaderNodeBackground")
    out = nt.nodes.new("ShaderNodeOutputWorld")
    maprange = nt.nodes.new("ShaderNodeMapRange")
    maprange.inputs["From Min"].default_value = -1.0
    maprange.inputs["From Max"].default_value = 1.0
    ramp.color_ramp.elements[0].position = 0.0
    ramp.color_ramp.elements[0].color = (0.18, 0.2, 0.19, 1)   # soft bounce from the green table
    ramp.color_ramp.elements[1].position = 1.0
    ramp.color_ramp.elements[1].color = (1.0, 1.0, 1.0, 1)      # neutral sky
    nt.links.new(coord.outputs["Generated"], sep.inputs["Vector"])
    nt.links.new(sep.outputs["Z"], maprange.inputs["Value"])
    nt.links.new(maprange.outputs["Result"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], bg.inputs["Color"])
    bg.inputs["Strength"].default_value = strength
    nt.links.new(bg.outputs["Background"], out.inputs["Surface"])


def setup_render(scene):
    if ENGINE == "CYCLES":
        scene.render.engine = "CYCLES"
        scene.cycles.device = "CPU"
        scene.cycles.samples = SAMPLES
        scene.cycles.use_denoising = True
        scene.cycles.max_bounces = 6
    else:
        for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
            try:
                scene.render.engine = eng
                break
            except TypeError:
                continue
        scene.eevee.taa_render_samples = 64
    scene.render.resolution_x = RENDER_PX
    scene.render.resolution_y = RENDER_PX
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.color_depth = "8"
    try:
        scene.view_settings.view_transform = "Standard"
    except TypeError:
        pass


def setup_camera(scene):
    cam_data = bpy.data.cameras.new("cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = 2.55
    cam = bpy.data.objects.new("cam", cam_data)
    cam.location = (0.0, -8.0, 0.0)
    cam.rotation_euler = (math.radians(90), 0.0, 0.0)
    scene.collection.objects.link(cam)
    scene.camera = cam


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out_dir = None
    only = None
    frames = FRAMES
    i = 0
    while i < len(argv):
        if argv[i] == "--out":
            out_dir = argv[i + 1]
            i += 2
        elif argv[i] == "--only":
            only = argv[i + 1].split(",")
            i += 2
        elif argv[i] == "--frames":
            frames = int(argv[i + 1])
            i += 2
        else:
            i += 1
    if not out_dir:
        raise SystemExit("usage: blender -b -P make_suits.py -- --out <dir> [--only H,S] [--frames 24]")

    for suit in SUITS:
        if only and suit not in only:
            continue
        scene = reset_scene()
        setup_render(scene)
        setup_world(scene, 0.30 if suit in ("H", "D") else 0.14)
        setup_camera(scene)
        # key (top-left-front), cool rim (back-right), soft strip fill (low-right)
        add_area_light("key", (-3.5, -5.0, 4.0), 6.0, 330)
        add_area_light("rim", (4.5, 3.0, 2.5), 4.0, 170, (0.9, 0.95, 1.0))
        add_area_light("fill", (4.0, -5.0, -1.5), 6.0, 90, (1.0, 0.97, 0.92))
        pivot = build_suit(suit)

        suit_dir = os.path.join(out_dir, suit)
        os.makedirs(suit_dir, exist_ok=True)
        for f in range(frames):
            pivot.rotation_euler = (0.0, 0.0, 2 * math.pi * f / frames)
            scene.render.filepath = os.path.join(suit_dir, f"f{f:02d}.png")
            bpy.ops.render.render(write_still=True)
        print(f"[make_suits] {suit}: {frames} frames -> {suit_dir}")


main()
