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

import bpy
from mathutils import Vector

FRAMES = 24
RENDER_PX = 384          # rendered big, downsampled to 256 by pack_suits.py (anti-aliasing)
SAMPLES = 96
SUITS = ["H", "D", "C", "S"]

# Linear-space base colours.
RED = (0.62, 0.015, 0.03, 1.0)
BLACK = (0.012, 0.012, 0.02, 1.0)


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
    bsdf.inputs["Roughness"].default_value = 0.22 if red else 0.16
    bsdf.inputs["Metallic"].default_value = 0.0
    for name, val in (("Coat Weight", 1.0), ("Coat Roughness", 0.04), ("Clearcoat", 1.0), ("Clearcoat Roughness", 0.04)):
        if name in bsdf.inputs:
            bsdf.inputs[name].default_value = val
    if "Specular IOR Level" in bsdf.inputs:
        bsdf.inputs["Specular IOR Level"].default_value = 0.7
    return mat


def make_shape_object(name, outline, mat):
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "2D"
    cu.fill_mode = "BOTH"
    cu.extrude = 0.10
    cu.bevel_depth = 0.075
    cu.bevel_resolution = 8
    cu.resolution_u = 4
    sp = cu.splines.new("POLY")
    sp.points.add(len(outline) - 1)
    for p, (x, y) in zip(sp.points, outline):
        p.co = (x, y, 0.0, 1.0)
    sp.use_cyclic_u = True
    ob = bpy.data.objects.new(name, cu)
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


def setup_world(scene):
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
    ramp.color_ramp.elements[0].color = (0.06, 0.07, 0.10, 1)   # dark floor
    ramp.color_ramp.elements[1].position = 1.0
    ramp.color_ramp.elements[1].color = (1.4, 1.5, 1.7, 1)      # bright sky
    nt.links.new(coord.outputs["Generated"], sep.inputs["Vector"])
    nt.links.new(sep.outputs["Z"], maprange.inputs["Value"])
    nt.links.new(maprange.outputs["Result"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], bg.inputs["Color"])
    bg.inputs["Strength"].default_value = 0.9
    nt.links.new(bg.outputs["Background"], out.inputs["Surface"])


def setup_render(scene):
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = SAMPLES
    scene.cycles.use_denoising = True
    scene.cycles.max_bounces = 6
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
        setup_world(scene)
        setup_camera(scene)
        # key (top-left-front), cool rim (back-right), soft strip fill (low-right)
        add_area_light("key", (-3.5, -5.0, 4.0), 4.0, 900)
        add_area_light("rim", (4.5, 3.0, 2.5), 3.0, 700, (0.75, 0.85, 1.0))
        add_area_light("fill", (4.0, -5.0, -1.5), 5.0, 260, (1.0, 0.95, 0.9))
        pivot = build_suit(suit)

        suit_dir = os.path.join(out_dir, suit)
        os.makedirs(suit_dir, exist_ok=True)
        for f in range(frames):
            pivot.rotation_euler = (0.0, 0.0, 2 * math.pi * f / frames)
            scene.render.filepath = os.path.join(suit_dir, f"f{f:02d}.png")
            bpy.ops.render.render(write_still=True)
        print(f"[make_suits] {suit}: {frames} frames -> {suit_dir}")


main()
