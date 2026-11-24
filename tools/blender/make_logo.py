"""Recreate the app logo (apps/mobile/assets/branding/logo.png) as a 3D scene in Blender.

Run (Blender 4.2+ / 5.x, headless):

    blender -b -P tools/blender/make_logo.py -- --out logo_3d.png [--size 1024] [--samples 96] [--save logo.blend]

A gold bevelled rounded-square frame around a green felt plate; on it a heart split into four
quadrants (hearts / diamonds / clubs / spades), each a bevelled glossy tile with its dark suit inlaid.
Layout is authored in the 1024px pixel space of the original logo and converted to scene units
(1 unit = 512 px, y up, centred), so it can be compared 1:1 with the flat PNG.
"""
import math
import os
import sys

import bpy
from mathutils import Vector

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))


def args():
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    o = {"out": os.path.join(REPO, "tools", "blender", "_logo_out", "logo_3d.png"), "size": 1024, "samples": 96, "save": None, "heart_only": False}
    for i, k in enumerate(a):
        if k == "--out":
            o["out"] = a[i + 1]
        elif k == "--size":
            o["size"] = int(a[i + 1])
        elif k == "--samples":
            o["samples"] = int(a[i + 1])
        elif k == "--heart-only":
            o["heart_only"] = True
        elif k == "--save":
            o["save"] = a[i + 1]
    return o


# ------------------------------------------------------------------ pixel space -> scene units
def P(px, py):
    return ((px - 512.0) / 512.0, (512.0 - py) / 512.0)


def lin(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def rgb(hexstr):
    h = hexstr.lstrip("#")
    return (lin(int(h[0:2], 16)), lin(int(h[2:4], 16)), lin(int(h[4:6], 16)), 1.0)


# ------------------------------------------------------------------ 2D outline builders (pixel space)
def rounded_rect(x0, y0, x1, y1, r, n=24):
    pts = []
    for cx, cy, a0 in ((x1 - r, y0 + r, -90), (x1 - r, y1 - r, 0), (x0 + r, y1 - r, 90), (x0 + r, y0 + r, 180)):
        for i in range(n + 1):
            a = math.radians(a0 + 90.0 * i / n)
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def circle_arc(cx, cy, r, a0, a1, n=64):
    """Points on a circle from angle a0 to a1 (degrees, screen space, y down)."""
    return [(cx + r * math.cos(math.radians(a0 + (a1 - a0) * i / n)), cy + r * math.sin(math.radians(a0 + (a1 - a0) * i / n))) for i in range(n + 1)]


def bezier(p0, p1, p2, p3, n=40):
    out = []
    for i in range(n + 1):
        t = i / n
        u = 1 - t
        out.append((u**3 * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t**3 * p3[0],
                    u**3 * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t**3 * p3[1]))
    return out


LOBE_RX = 196.0
LOBE_RY = 185.0
LOBE_Y = 370.0
GAP_L, GAP_R = 500.0, 524.0       # vertical gap between left/right pieces
CUT_TOP, CUT_BOT = 468.0, 493.0   # horizontal gap between upper lobes and lower points


def lobe_piece(cx, side):
    """Upper quadrant: a circle clipped by the vertical centre gap (x) and the horizontal cut (y)."""
    pts = []
    n = 160
    for i in range(n + 1):
        a = 2 * math.pi * i / n
        x, y = cx + LOBE_RX * math.cos(a), LOBE_Y + LOBE_RY * math.sin(a)
        x = min(x, GAP_L) if side < 0 else max(x, GAP_R)
        y = min(y, CUT_TOP)
        pts.append((x, y))
    # dedupe consecutive repeats (clamping creates runs of identical points)
    out = []
    for p in pts:
        if not out or abs(p[0] - out[-1][0]) + abs(p[1] - out[-1][1]) > 1e-3:
            out.append(p)
    return out


def point_piece(side):
    """Lower quadrant: the heart's tapering point, cut flat at the top, curved on the outside."""
    tip = (500.0, 828.0)
    start = (178.0, 493.0)
    curve = bezier(start, (300.0, 660.0), (440.0, 740.0), tip)   # outer edge, top-left -> tip
    pts = curve + [(500.0, 493.0)]
    if side > 0:
        pts = [(1024 - x, y) for x, y in pts]
    return pts


# ------------------------------------------------------------------ suit glyphs (y up, from make_suits.py)
def circle(cx, cy, r, n=48):
    return [(cx + r * math.cos(2 * math.pi * i / n), cy + r * math.sin(2 * math.pi * i / n)) for i in range(n)]


def heart_points(n=120):
    pts = []
    for i in range(n):
        t = 2 * math.pi * i / n
        x = 16 * math.sin(t) ** 3
        y = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
        pts.append((x / 17.0, (y + 2.5) / 17.0))
    return pts


def stem_points(top_y, bottom_y, top_w=0.09, bottom_w=0.30):
    steps = 8
    right, left = [], []
    for i in range(steps + 1):
        f = i / steps
        y = top_y + (bottom_y - top_y) * f
        w = top_w + (bottom_w - top_w) * (f ** 2.2)
        right.append((w, y))
        left.append((-w, y))
    return right + left[::-1]


GLYPHS = {
    # suit: (outlines in glyph space (y up), target bbox in logo pixels (x0, y0, x1, y1), y down)
    "H": ([heart_points()], (296, 293, 462, 442)),
    "D": ([[(0.0, 1.0), (0.66, 0.0), (0.0, -1.0), (-0.66, 0.0)]], (575, 262, 715, 454)),
    "C": ([circle(0.0, 0.46, 0.34), circle(-0.42, -0.08, 0.34), circle(0.42, -0.08, 0.34), circle(0.0, 0.05, 0.30),
           stem_points(-0.1, -0.98)], (329, 530, 490, 692)),
    "S": ([[(x, -y) for x, y in heart_points()], stem_points(-0.25, -0.98)], (531, 497, 691, 692)),
}


def fit_glyph(outlines, bbox):
    xs = [p[0] for o in outlines for p in o]
    ys = [p[1] for o in outlines for p in o]
    gx0, gx1, gy0, gy1 = min(xs), max(xs), min(ys), max(ys)
    x0, y0, x1, y1 = bbox
    sx, sy = (x1 - x0) / (gx1 - gx0), (y1 - y0) / (gy1 - gy0)
    return [[(x0 + (x - gx0) * sx, y1 - (y - gy0) * sy) for x, y in o] for o in outlines]


# ------------------------------------------------------------------ Blender helpers
def make_curve(name, outlines, extrude, bevel, bevel_res=6, z=0.0, mat=None):
    """Filled, extruded, bevelled shape from one or more closed pixel-space outlines (extra outlines = holes)."""
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "2D"
    cu.fill_mode = "BOTH"
    cu.extrude = extrude
    cu.bevel_depth = bevel
    cu.bevel_resolution = bevel_res
    cu.resolution_u = 2
    for o in outlines:
        sp = cu.splines.new("POLY")
        sp.points.add(len(o) - 1)
        for pt, (x, y) in zip(sp.points, o):
            ux, uy = P(x, y)
            pt.co = (ux, uy, 0.0, 1.0)
        sp.use_cyclic_u = True
    ob = bpy.data.objects.new(name, cu)
    bpy.context.scene.collection.objects.link(ob)
    ob.location.z = z
    if mat:
        ob.data.materials.append(mat)
    return ob


def gradient_material(name, top, bottom, roughness=0.32, coat=0.5, metallic=0.0, y_top=1.0, y_bottom=-1.0, radial=False):
    """Principled material whose base colour is a gradient in scene space (Object coordinates).

    Linear: `top` at y_top (units), `bottom` at y_bottom. radial=True: `top` at the centre, `bottom` at
    radius |y_top| (used for the felt vignette).
    """
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Object"], sep.inputs[0])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = top
    ramp.color_ramp.elements[1].color = bottom
    if radial:
        vec = nt.nodes.new("ShaderNodeVectorMath"); vec.operation = "LENGTH"
        flat = nt.nodes.new("ShaderNodeCombineXYZ")
        nt.links.new(sep.outputs[0], flat.inputs[0]); nt.links.new(sep.outputs[1], flat.inputs[1])
        nt.links.new(flat.outputs[0], vec.inputs[0])
        mr = nt.nodes.new("ShaderNodeMapRange")
        mr.inputs[1].default_value = 0.0; mr.inputs[2].default_value = abs(y_top)
        nt.links.new(vec.outputs["Value"], mr.inputs[0])
    else:
        mr = nt.nodes.new("ShaderNodeMapRange")
        mr.inputs[1].default_value = y_top; mr.inputs[2].default_value = y_bottom
        nt.links.new(sep.outputs[1], mr.inputs[0])
    mr.clamp = True
    nt.links.new(mr.outputs[0], ramp.inputs[0])
    nt.links.new(ramp.outputs[0], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    for key, val in (("Coat Weight", coat), ("Clearcoat", coat), ("Coat Roughness", 0.12), ("Clearcoat Roughness", 0.12)):
        if key in bsdf.inputs:
            bsdf.inputs[key].default_value = val
    return mat


def flat_material(name, color, roughness=0.5, coat=0.2):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Roughness"].default_value = roughness
    for key, val in (("Coat Weight", coat), ("Clearcoat", coat), ("Coat Roughness", 0.2), ("Clearcoat Roughness", 0.2)):
        if key in bsdf.inputs:
            bsdf.inputs[key].default_value = val
    return mat


# ------------------------------------------------------------------ scene
def build(heart_only=False):
    bpy.ops.wm.read_factory_settings(use_empty=True)

    # materials (colours sampled from the flat logo)
    gold = gradient_material("gold", rgb("#FFE07A"), rgb("#C48A22"), roughness=0.3, coat=0.5, metallic=0.6, y_top=1.0, y_bottom=-1.0)
    felt = gradient_material("felt", rgb("#3B8A5B"), rgb("#124428"), roughness=0.85, coat=0.0, y_top=1.45, radial=True)
    red = gradient_material("red", rgb("#FF6B6E"), rgb("#EC4A58"), y_top=0.55, y_bottom=0.08)
    yellow = gradient_material("yellow", rgb("#FFDF73"), rgb("#F0BC45"), y_top=0.55, y_bottom=0.08)
    green = gradient_material("green", rgb("#6FCF8F"), rgb("#3FAE6A"), y_top=0.04, y_bottom=-0.62)
    cream = gradient_material("cream", rgb("#E9E1CA"), rgb("#D2C6A8"), y_top=0.04, y_bottom=-0.62)
    ink = {
        "H": flat_material("ink_H", rgb("#3E382E"), 0.45, 0.25),
        "D": flat_material("ink_D", rgb("#40512D"), 0.45, 0.25),
        "C": flat_material("ink_C", rgb("#1F4F35"), 0.45, 0.25),
        "S": flat_material("ink_S", rgb("#3C5648"), 0.45, 0.25),
    }

    # frame: gold ring (outer rounded square minus inner), felt plate sunk inside it
    outer = rounded_rect(0, 0, 1024, 1024, 232)
    inner = rounded_rect(36, 36, 988, 988, 196)
    if not heart_only:
      make_curve("frame", [outer, inner], extrude=0.035, bevel=0.028, z=0.0, mat=gold)
      make_curve("felt", [rounded_rect(34, 34, 990, 990, 198)], extrude=0.0, bevel=0.0, z=-0.005, mat=felt)

    # quadrant tiles
    tiles = [
        ("tile_H", [lobe_piece(332.0, -1)], red, "H"),
        ("tile_D", [lobe_piece(692.0, +1)], yellow, "D"),
        ("tile_C", [point_piece(-1)], green, "C"),
        ("tile_S", [point_piece(+1)], cream, "S"),
    ]
    for name, outlines, mat, suit in tiles:
        make_curve(name, outlines, extrude=0.022, bevel=0.016, z=0.03, mat=mat)
        glyph = fit_glyph(*GLYPHS[suit])
        for k, outline in enumerate(glyph):   # separate objects: overlapping outlines in one curve would cut holes
            make_curve(f"glyph_{suit}{k}", [outline], extrude=0.012, bevel=0.0, z=0.07 + k * 0.0008, mat=ink[suit])

    # camera: orthographic, straight down, exactly framing the 2x2 logo
    cam_data = bpy.data.cameras.new("cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = 2.0
    cam = bpy.data.objects.new("cam", cam_data)
    bpy.context.scene.collection.objects.link(cam)
    cam.location = (0, 0, 6)
    bpy.context.scene.camera = cam

    # lights: big soft key from the top-left (rim highlights on the upper-left edges, shadows fall down-right),
    # gentle fill, so the bevels read like the highlights in the flat logo.
    def area(name, loc, energy, size, color=(1, 1, 1)):
        ld = bpy.data.lights.new(name, "AREA")
        ld.energy = energy
        ld.size = size
        ld.color = color
        ob = bpy.data.objects.new(name, ld)
        bpy.context.scene.collection.objects.link(ob)
        ob.location = loc
        direction = Vector((0, 0, 0)) - Vector(loc)
        ob.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
        return ob

    area("key", (-2.6, 3.0, 3.6), 380, 3.5, (1.0, 0.96, 0.90))
    area("fill", (3.0, -2.0, 4.0), 160, 4.0, (0.9, 0.95, 1.0))

    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (0.9, 0.95, 1.0, 1.0)
    bg.inputs["Strength"].default_value = 0.2
    bpy.context.scene.world = world


def render(opts):
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.samples = opts["samples"]
    sc.cycles.use_denoising = True
    sc.cycles.device = "CPU"
    sc.render.resolution_x = sc.render.resolution_y = opts["size"]
    sc.render.resolution_percentage = 100
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    try:
        sc.view_settings.view_transform = "Standard"
    except Exception:
        pass
    os.makedirs(os.path.dirname(os.path.abspath(opts["out"])), exist_ok=True)
    sc.render.filepath = opts["out"]
    bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    o = args()
    build(o["heart_only"])
    if o["save"]:
        bpy.ops.wm.save_as_mainfile(filepath=o["save"])
    render(o)
    print("wrote", o["out"])
