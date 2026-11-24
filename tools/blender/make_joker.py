"""Joker card lion: a cartoon 3D lion head that roars (Blender script).

Run (Blender 4.2+ / 5.x, headless; use ABSOLUTE --out paths):

    blender -b -P tools/blender/make_joker.py -- --still --color red --out <dir>
    blender -b -P tools/blender/make_joker.py -- --poses --plist 0,0.12,0.3,0.5,0.85 --color black --out <dir>
    blender -b -P tools/blender/make_joker.py -- --color red --frames 36 --out <dir>   # full roar -> <dir>/<color>/f00.png..

Character faces -y, camera at -y looking +y, z up, orthographic, transparent background.
`roar(p)` takes p in 0..1 (0 and 1 = resting face) so the loop is seamless:
  0.00-0.24 anticipation (inhale: head dips, mane tightens, eyes widen)
  0.20-0.34 snap open (jaw drops, head thrusts up, mane flares)
  0.34-0.70 hold (roaring tremble)
  0.70-0.96 release back to rest
"""
import math
import os
import random
import sys

import bpy
from mathutils import Vector

TAU = math.tau
FACE_SCALE = 1.30     # the whole face is scaled up inside the mane
HAIR_R0, HAIR_R1 = 0.62, 1.35   # radial range of the hair colour gradient
SAMPLES = 48
ENGINE = os.environ.get("JOKER_ENGINE", "EEVEE")   # or CYCLES

# sRGB. Mane gradient root -> mid -> tip; roots are darker so the locks have depth.
MANE = {
    "red": {"root": (0.38, 0.03, 0.06), "mid": (0.78, 0.10, 0.13), "tip": (0.98, 0.34, 0.26)},
    "black": {"root": (0.05, 0.05, 0.07), "mid": (0.20, 0.20, 0.25), "tip": (0.50, 0.50, 0.60)},
}
FACE = (0.96, 0.72, 0.32)
FACE_DARK = (0.85, 0.52, 0.22)
MUZZLE = (1.0, 0.91, 0.70)
INK = (0.10, 0.07, 0.07)


def args():
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    o = {"out": "joker_out", "color": "red", "size": 512, "mode": "still", "frames": 36,
         "plist": [0.0, 0.12, 0.3, 0.5, 0.85]}
    i = 0
    while i < len(a):
        if a[i] == "--out":
            o["out"] = a[i + 1]; i += 1
        elif a[i] == "--color":
            o["color"] = a[i + 1]; i += 1
        elif a[i] == "--size":
            o["size"] = int(a[i + 1]); i += 1
        elif a[i] == "--frames":
            o["frames"] = int(a[i + 1]); o["mode"] = "anim"; i += 1
        elif a[i] == "--idle":
            o["frames"] = int(a[i + 1]); o["mode"] = "idle"; i += 1
        elif a[i] == "--plist":
            o["plist"] = [float(x) for x in a[i + 1].split(",")]; i += 1
        elif a[i] == "--still":
            o["mode"] = "still"
        elif a[i] == "--poses":
            o["mode"] = "poses"
        i += 1
    return o


def lin(c):
    f = lambda v: v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4
    return (f(c[0]), f(c[1]), f(c[2]), 1.0)


def _set_spec(b, spec):
    for k in ("Specular IOR Level", "Specular"):
        if k in b.inputs:
            b.inputs[k].default_value = spec
            return


def material(name, rgb, rough=0.45, spec=0.35):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = lin(rgb)
    b.inputs["Roughness"].default_value = rough
    _set_spec(b, spec)
    return m


def hair_material(name, mc, rough=0.42, spec=0.55):
    """Soft hair: colour is a radial gradient (distance from the head centre: dark root -> bright tip),
    shifted a little per strand by Object Info Random so locks do not look identical."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    b.inputs["Roughness"].default_value = rough
    _set_spec(b, spec)
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    vl = nt.nodes.new("ShaderNodeVectorMath")
    vl.operation = "LENGTH"
    rng = nt.nodes.new("ShaderNodeMapRange")
    rng.inputs["From Min"].default_value = HAIR_R0
    rng.inputs["From Max"].default_value = HAIR_R1
    rng.clamp = True
    oi = nt.nodes.new("ShaderNodeAttribute")
    oi.attribute_name = "rnd"
    rsh = nt.nodes.new("ShaderNodeMath")
    rsh.operation = "MULTIPLY_ADD"
    rsh.inputs[1].default_value = 0.22
    rsh.inputs[2].default_value = -0.11
    add = nt.nodes.new("ShaderNodeMath")
    add.operation = "ADD"
    add.use_clamp = True
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    nt.links.new(geo.outputs["Position"], vl.inputs[0])
    nt.links.new(vl.outputs["Value"], rng.inputs["Value"])
    nt.links.new(oi.outputs["Fac"], rsh.inputs[0])
    nt.links.new(rng.outputs["Result"], add.inputs[0])
    nt.links.new(rsh.outputs["Value"], add.inputs[1])
    nt.links.new(add.outputs["Value"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], b.inputs["Base Color"])
    cr = ramp.color_ramp
    cr.elements[0].position = 0.0
    cr.elements[0].color = lin(mc["root"])
    cr.elements[1].position = 1.0
    cr.elements[1].color = lin(mc["tip"])
    e = cr.elements.new(0.5)
    e.color = lin(mc["mid"])
    return m


def shade(o, mat, parent=None):
    for p in o.data.polygons:
        p.use_smooth = True
    o.data.materials.append(mat)
    if parent is not None:
        o.parent = parent
    return o


def sphere(name, r, loc, scale=(1, 1, 1), mat=None, parent=None, seg=32):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=loc, segments=seg, ring_count=seg // 2)
    o = bpy.context.object
    o.name = name
    o.scale = scale
    return shade(o, mat, parent)


def cone(name, r1, r2, depth, loc, rot, mat, parent=None, verts=24):
    bpy.ops.mesh.primitive_cone_add(radius1=r1, radius2=r2, depth=depth, location=loc, rotation=rot, vertices=verts)
    o = bpy.context.object
    o.name = name
    return shade(o, mat, parent)


def empty(name, loc, parent=None):
    o = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(o)
    o.location = loc
    o.parent = parent
    return o


def clamp01(x):
    return max(0.0, min(1.0, x))


def smooth(a, b, x):
    t = clamp01((x - a) / (b - a))
    return t * t * (3 - 2 * t)


def mouth_material(name):
    """Mouth interior: near-black throat in the middle, warm red toward the rim, so it reads as depth."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    b.inputs["Roughness"].default_value = 0.35
    _set_spec(b, 0.5)
    at = nt.nodes.new("ShaderNodeAttribute")
    at.attribute_name = "g"
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    nt.links.new(at.outputs["Fac"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], b.inputs["Base Color"])
    cr = ramp.color_ramp
    cr.elements[0].position = 0.12
    cr.elements[0].color = lin((0.05, 0.004, 0.012))
    cr.elements[1].position = 0.62
    cr.elements[1].color = lin((0.50, 0.07, 0.11))
    e = cr.elements.new(0.36)
    e.color = lin((0.24, 0.025, 0.05))
    return m


def tongue_material(name):
    """Glossy tongue: dark at the root (back), bright pink at the front."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    b.inputs["Roughness"].default_value = 0.28
    _set_spec(b, 0.8)
    at = nt.nodes.new("ShaderNodeAttribute")
    at.attribute_name = "g"
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    nt.links.new(at.outputs["Fac"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], b.inputs["Base Color"])
    cr = ramp.color_ramp
    cr.elements[0].position = 0.0
    cr.elements[0].color = lin((1.0, 0.50, 0.55))
    cr.elements[1].position = 1.0
    cr.elements[1].color = lin((0.45, 0.07, 0.12))
    return m


class Lion:
    """All the parts, grouped so `roar` can pose them."""

    def __init__(self, color):
        rnd = random.Random(11)
        mc = MANE[color]
        self.root = empty("root", (0, 0, 0))
        self.head = empty("head", (0, 0, 0), self.root)

        mats = {
            "face": material("face", FACE, 0.5, 0.25),
            "face_d": material("face_d", FACE_DARK, 0.5, 0.2),
            "muzzle": material("muzzle", MUZZLE, 0.55, 0.2),
            "ink": material("ink", INK, 0.3, 0.6),
            "nose": material("nose", (0.30, 0.12, 0.14), 0.25, 0.7),
            "white": material("white", (1.0, 1.0, 1.0), 0.2, 0.6),
            "mouth": mouth_material("mouth"),
            "gum": material("gum", (0.86, 0.38, 0.43), 0.4, 0.5),
            "lip": material("lip", (0.80, 0.50, 0.38), 0.5, 0.25),
            "tongue": tongue_material("tongue"),
            "teeth": material("teeth", (1.0, 0.98, 0.92), 0.3, 0.45),
            "ear_in": material("ear_in", (0.60, 0.33, 0.15), 0.55, 0.2),
        }

        # ---- mane: curved, tapered hair strands (NURBS curves with a bevel), rebuilt every pose.
        self.face = empty("face", (0, 0, 0), self.head)
        self.face.scale = (FACE_SCALE,) * 3
        hair = hair_material("hair", mc)
        tcu = bpy.data.curves.new("taper", "CURVE")
        tsp = tcu.splines.new("POLY")
        tsp.points.add(3)
        for i, (x, y) in enumerate(((0.0, 1.0), (0.4, 0.98), (0.75, 0.74), (1.0, 0.05))):
            tsp.points[i].co = (x, y, 0.0, 1.0)
        taper = bpy.data.objects.new("taper", tcu)
        bpy.context.collection.objects.link(taper)
        taper.hide_render = True
        taper.hide_viewport = True

        self.locks = []
        # (count, root radius, strand radius, base length, depth y, curl, droop)
        layers = [(26, 0.52, 0.135, 0.78, 0.34, 0.42, 0.26), (24, 0.52, 0.125, 0.64, 0.22, 0.40, 0.20),
                  (20, 0.52, 0.115, 0.50, 0.10, 0.36, 0.12), (40, 0.54, 0.055, 0.80, 0.28, 0.50, 0.28)]
        for li, (n, r0, w, ln, yd, curl, droop) in enumerate(layers):
            for ci in range(n):
                a = TAU * (ci + 0.5 * (li % 2)) / n + rnd.uniform(-0.05, 0.05)
                sil = (1.0 + 0.18 * math.sin(a)) * (1.0 + 0.08 * math.cos(2 * a))
                L = ln * sil * rnd.uniform(0.92, 1.08)
                cu = bpy.data.curves.new("lock", "CURVE")
                cu.dimensions = "3D"
                cu.bevel_depth = w
                cu.bevel_resolution = 3
                cu.taper_object = taper
                cu.resolution_u = 10
                sp = cu.splines.new("NURBS")
                sp.points.add(5)
                sp.order_u = 4
                sp.use_endpoint_u = True
                cu.materials.append(hair)
                ob = bpy.data.objects.new("lock", cu)
                bpy.context.collection.objects.link(ob)
                ob.parent = self.head
                ob["gk"] = "hair"
                ob["rnd"] = rnd.random()
                self.locks.append({"sp": sp, "a": a, "L": L, "r0": r0 + rnd.uniform(-0.02, 0.03), "y": yd + rnd.uniform(-0.02, 0.02),
                                   "curl": curl * rnd.uniform(0.8, 1.15) * (-1 if math.cos(a) > 0 else 1),   # mirrored: strands sweep down on both sides
                                   "droop": droop * rnd.uniform(0.7, 1.2), "ph": rnd.uniform(0, TAU)})

        # ---- head, ears (small, rounded, tucked into the mane), cheek ruff, muzzle
        skull = sphere("skull", 0.50, (0, 0, 0), (1.10, 0.86, 0.94), mats["face"], self.face, 48)
        # not a ball: push the outline toward a rounded square (superellipse), flatter forehead, broader jaw
        for v in skull.data.vertices:
            x, z = v.co.x / 0.5, v.co.z / 0.5
            r = math.hypot(x, z)
            if r > 1e-6:
                n = (x ** 4 + z ** 4) ** 0.25
                k = 1.0 + 0.28 * (r / n - 1.0)
                v.co.x *= k
                v.co.z *= k
                if v.co.z > 0:
                    v.co.z *= 0.95                       # flatter forehead
                elif v.co.z < -0.1:
                    v.co.x *= 1.0 + 0.06 * min(1.0, (-v.co.z - 0.1) / 0.3)   # fuller jaw / cheeks
        for sx in (-1, 1):
            sphere("ear", 0.17, (sx * 0.44, -0.02, 0.36), (1.0, 0.55, 1.0), mats["face"], self.face, 24)
            sphere("ear_in", 0.10, (sx * 0.44, -0.08, 0.355), (1.0, 0.4, 1.0), mats["ear_in"], self.face, 20)
        for sx in (-1, 1):
            sphere("pad", 0.16, (sx * 0.15, -0.40, -0.12), (1.0, 0.55, 0.85), mats["muzzle"], self.face, 32)
            sphere("pad2", 0.11, (sx * 0.235, -0.36, -0.07), (1.0, 0.5, 0.85), mats["muzzle"], self.face, 24)
        sphere("muzzle_top", 0.17, (0, -0.44, -0.06), (1.4, 0.65, 0.8), mats["muzzle"], self.face, 32)
        sphere("nose", 0.088, (0, -0.55, 0.035), (1.3, 0.8, 0.85), mats["nose"], self.face, 24)
        sphere("nose_hi", 0.024, (-0.03, -0.62, 0.058), (1, 0.6, 0.8), mats["white"], self.face, 12)
        for sx in (-1, 1):
            for (dx, dz) in ((0.04, 0.0), (0.09, -0.04), (0.05, -0.06)):
                sphere("dot", 0.012, (sx * (0.19 + dx), -0.58, -0.06 + dz), (1, 0.6, 1), mats["ink"], self.face, 8)

        # ---- brows (move for the roar)
        self.brows = []
        for sx in (-1, 1):
            b = sphere("brow", 0.10, (sx * 0.245, -0.40, 0.285), (1.5, 0.7, 0.45), mats["face_d"], self.face, 24)
            self.brows.append((b, sx))

        # ---- eyes: big, with two glints
        self.eyes = []
        for sx in (-1, 1):
            eye = empty("eye", (sx * 0.235, -0.43, 0.13), self.face)
            sphere("eyewhite", 0.085, (0, 0, 0), (1, 0.55, 1.08), mats["white"], eye, 28)
            sphere("pupil", 0.055, (sx * -0.005, -0.034, 0.0), (1, 0.5, 1.12), mats["ink"], eye, 24)
            sphere("glint", 0.020, (sx * 0.015 - 0.009, -0.065, 0.024), (1, 0.6, 1), mats["white"], eye, 10)
            sphere("glint2", 0.009, (sx * -0.015 + 0.009, -0.065, -0.019), (1, 0.6, 1), mats["white"], eye, 8)
            lid = sphere("lid", 0.095, (0, -0.009, 0.0), (1.05, 0.55, 0.55), mats["face"], eye, 24)
            lid.location.z = 0.152
            self.eyes.append((eye, lid, sx))

        # ---- mouth: deep cavity, lip ring + chin pad, gum band, graded teeth, grooved tongue
        self.mouth = sphere("mouth_in", 0.17, (0, -0.42, -0.27), (1.45, 0.45, 0.1), mats["mouth"], self.face, 28)
        self.mouth["gk"] = "mouth"
        self.jaw = empty("jaw", (0, -0.34, -0.19), self.face)
        self.chin = sphere("chin", 0.17, (0, -0.10, -0.10), (1.25, 0.9, 0.62), mats["muzzle"], self.jaw, 32)
        bpy.ops.mesh.primitive_torus_add(major_radius=0.165, minor_radius=0.020, location=(0, -0.44, -0.27),
                                         rotation=(math.pi / 2, 0, 0), major_segments=48, minor_segments=14)
        self.lip = shade(bpy.context.object, mats["lip"], self.face)      # thick lip framing the opening
        self.lip.name = "lip"
        self.gum = sphere("gum", 0.12, (0, -0.465, -0.205), (1.5, 0.5, 0.22), mats["gum"], self.face, 24)
        self.flews = []
        self.tongue = empty("tongue", (0, -0.25, -0.03), self.jaw)
        for lx in (-0.05, 0.05):
            sphere("lobe", 0.115, (lx, 0, 0), (0.62, 1.0, 1.0), mats["tongue"], self.tongue, 24)["gk"] = "tongue"
        sphere("root", 0.10, (0, 0.07, -0.01), (1.0, 1.0, 0.8), mats["tongue"], self.tongue, 20)["gk"] = "tongue"
        self.teeth = []
        for sx in (-1, 1):
            # lower: fangs well in front of the tongue
            self.teeth.append(cone("fang_low", 0.032, 0.002, 0.13, (sx * 0.115, -0.31, 0.0), (0, 0, 0), mats["teeth"], self.jaw))
            self.teeth.append(cone("tooth_low", 0.015, 0.002, 0.05, (sx * 0.06, -0.315, -0.01), (0, 0, 0), mats["teeth"], self.jaw, 12))
            # upper: canine fang (long), incisors (short), premolar; all rooted on the gum line z = -0.228
            self.teeth.append(cone("fang_up", 0.036, 0.002, 0.16, (sx * 0.115, -0.47, -0.285), (math.pi, sx * 0.12, 0), mats["teeth"], self.face))
            for x in (0.030, 0.066):
                self.teeth.append(cone("tooth_up", 0.016, 0.002, 0.065, (sx * x, -0.47, -0.2375), (math.pi, 0, 0), mats["teeth"], self.face, 12))
            self.teeth.append(cone("prem_up", 0.020, 0.002, 0.085, (sx * 0.16, -0.465, -0.2475), (math.pi, -sx * 0.10, 0), mats["teeth"], self.face, 12))

    def roar(self, p):
        """p in 0..1: 0 and 1 = resting face."""
        p = clamp01(p)
        ant = math.sin(math.pi * p / 0.24) if p < 0.24 else 0.0            # inhale
        opn = smooth(0.20, 0.34, p) - smooth(0.70, 0.96, p)                # 0 -> 1 -> hold -> 0
        snap = math.sin(math.pi * clamp01((p - 0.20) / 0.22)) if p < 0.42 else 0.0   # overshoot as it opens
        shake = math.sin(p * TAU * 9) * (opn ** 2)                          # roaring tremble

        self.mouth.scale = (1.45 + 0.30 * opn, 0.45, 0.10 + 1.6 * opn)
        self.mouth.location.y = -0.42 + 0.11 * opn                         # cavity sinks behind the chin / lower teeth as it opens
        self.jaw.rotation_euler = (math.radians(75 * opn + 10 * snap), 0, 0)
        self.tongue.scale = (1.15, 1.1, 0.40 * opn)                         # hidden at rest
        k = smooth(0.04, 0.2, opn)
        self.lip.location = (0, self.mouth.location.y - 0.02, -0.27)
        self.lip.scale = ((1.45 + 0.30 * opn) * k + 1e-3, (0.10 + 1.6 * opn) * k + 1e-3, k + 1e-3)   # lip ring hugs the opening
        gs = smooth(0.05, 0.5, opn)
        self.gum.scale = (1.5 * gs + 1e-3, 0.5 * gs + 1e-3, 0.22 * gs + 1e-3)
        for f in self.flews:
            f.scale = (1.25 * gs + 1e-3, 0.8 * gs + 1e-3, 0.8 * gs + 1e-3)
        ang = math.radians(75 * opn + 10 * snap)
        for t in self.teeth:
            if t.parent is self.jaw:
                t.rotation_euler = (-ang * 0.95, 0, 0)                      # lower teeth stay upright as the jaw drops
        self.tongue.rotation_euler = (-ang * 0.8, 0, 0)
        ts = smooth(0.05, 0.5, opn)                                         # teeth only show once the mouth is open
        for t in self.teeth:
            t.scale = (ts, ts, ts)
        self.head.rotation_euler = (math.radians(-11 * opn + 6 * ant), 0, math.radians(2.0) * shake)
        s = 1 + 0.07 * opn - 0.035 * ant
        self.head.scale = (s, s, s)
        self.head.location = (0.012 * shake, 0, 0.03 * opn - 0.02 * ant)

        for eye, lid, sx in self.eyes:
            lid.location.z = 0.152 - 0.068 * opn + 0.015 * ant                 # wide on the inhale, angry glare on the roar
            lid.rotation_euler = (0, -sx * math.radians(26) * opn, 0)      # inner corner down = angry glare
        for b, sx in self.brows:
            b.rotation_euler = (0, -sx * math.radians(3) - sx * math.radians(26) * opn + sx * math.radians(8) * ant, 0)
            b.location = (sx * 0.245, -0.40, 0.285 - 0.035 * opn + 0.03 * ant)

        for l in self.locks:
            a, L = l["a"], l["L"]
            f = 0.26 * opn - 0.07 * ant + 0.05 * math.sin(l["a"] * 3 + p * TAU * 2) * opn   # flare / ripple, rooted at the head
            d = Vector((math.cos(a), 0, math.sin(a)))
            tg = Vector((-math.sin(a), 0, math.cos(a)))
            curl = l["curl"] * (1 - 0.55 * opn)                                 # strands straighten as they flare
            droop = l["droop"] * (1 - 0.7 * opn)
            sway = 0.03 * math.sin(l["ph"] + p * TAU) * (0.4 + opn)             # gentle breathing sway
            for i, pt in enumerate(l["sp"].points):
                sfrac = i / 5.0
                pos = d * (l["r0"] + L * (1 + f) * sfrac) + tg * (curl * L * (0.9 * sfrac * sfrac - 0.1 * sfrac) + sway * sfrac)
                pos += Vector((0, l["y"] + 0.06 * sfrac, -droop * L * sfrac * sfrac))
                pt.co = (pos.x, pos.y, pos.z, 1.0)
        return opn

    def idle(self, p):
        """Looping idle, p in 0..1 (one loop = 1.25 s). Same pose as roar(0) at p = 0 and p = 1."""
        self.roar(0.0)                                        # rest pose, everything else reset
        w = math.sin(TAU * p)
        s = 1.0 + 0.014 * w
        self.head.scale = (s, s, s)                           # breathing
        self.head.location = (0, 0, 0.010 * w)
        self.head.rotation_euler = (math.radians(1.4) * math.sin(TAU * p + 0.7) - math.radians(1.4) * math.sin(0.7), 0, math.radians(0.9) * math.sin(TAU * p))
        # one blink per loop, ~0.13 s
        b = math.sin(math.pi * (p - 0.55) / 0.11) if 0.55 <= p <= 0.66 else 0.0
        for eye, lid, sx in self.eyes:
            lid.location = (0, -0.009 - 0.045 * b, 0.152 * (1.0 - b))     # forward as it closes so it covers the glints
            lid.scale = (1.05, 0.55 + 0.35 * b, 0.55 + 0.5 * b)
        for l in self.locks:
            a, L = l["a"], l["L"]
            f = 0.018 * math.sin(TAU * p + a * 2) * 0.5 + 0.0       # mane swells a touch with each breath
            d = Vector((math.cos(a), 0, math.sin(a)))
            tg = Vector((-math.sin(a), 0, math.cos(a)))
            sway = 0.012 * math.sin(l["ph"]) + 0.045 * (math.sin(l["ph"] + TAU * p) - math.sin(l["ph"]))
            for i, pt in enumerate(l["sp"].points):
                sfrac = i / 5.0
                pos = d * (l["r0"] + L * (1 + f) * sfrac) + tg * (l["curl"] * L * (0.9 * sfrac * sfrac - 0.1 * sfrac) + sway * sfrac)
                pos += Vector((0, l["y"] + 0.06 * sfrac, -l["droop"] * L * sfrac * sfrac))
                pt.co = (pos.x, pos.y, pos.z, 1.0)


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def look_at(obj, target):
    d = Vector(target) - obj.location
    obj.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()


def add_area_light(name, loc, size, energy, color=(1, 1, 1)):
    ld = bpy.data.lights.new(name, "AREA")
    ld.energy = energy
    ld.size = size
    ld.color = color
    o = bpy.data.objects.new(name, ld)
    bpy.context.collection.objects.link(o)
    o.location = loc
    look_at(o, (0, 0, 0))


def setup_world(scene, strength=0.5):
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    scene.world = world
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (0.9, 0.92, 1.0, 1.0)
    bg.inputs["Strength"].default_value = strength


def setup_render(scene, size):
    ok = False
    if ENGINE == "CYCLES":
        scene.render.engine = "CYCLES"
        scene.cycles.samples = SAMPLES
        ok = True
    else:
        for eng in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE"):
            try:
                scene.render.engine = eng
                ok = True
                break
            except TypeError:
                continue
        for attr, val in (("taa_render_samples", SAMPLES), ("use_gtao", True), ("gtao_distance", 0.6),
                          ("use_soft_shadows", True)):
            try:
                setattr(scene.eevee, attr, val)
            except Exception:
                pass
    if not ok:
        scene.render.engine = "CYCLES"
    scene.render.film_transparent = True
    scene.render.resolution_x = size
    scene.render.resolution_y = size
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.view_settings.view_transform = "Standard"


def setup_camera(scene):
    cd = bpy.data.cameras.new("cam")
    cd.type = "ORTHO"
    cd.ortho_scale = 3.9
    cam = bpy.data.objects.new("cam", cd)
    bpy.context.collection.objects.link(cam)
    cam.location = (0, -6, 0)
    cam.rotation_euler = (math.radians(90), 0, 0)
    scene.camera = cam


POSE_KEYS = [0.0, 0.06, 0.12, 0.18, 0.24, 0.30, 0.36, 0.42, 0.50, 0.60, 0.70, 0.78, 0.86, 0.93, 1.0]
IDLE_N = 15                                    # idle keys every 1/15 of the loop; p = 0 and 1 are the Basis
IDLE_KEYS = [k / IDLE_N for k in range(1, IDLE_N)]


def _eval_part(ob, dg):
    oe = ob.evaluated_get(dg)
    me = oe.to_mesh()
    mw = oe.matrix_world.copy()
    world = [tuple(mw @ v.co) for v in me.vertices]
    local = [tuple(v.co) for v in me.vertices]
    faces = [tuple(p.vertices) for p in me.polygons]
    oe.to_mesh_clear()
    return world, local, faces


def bake_single_mesh(lion):
    """Merge every part into one mesh object. Poses become shape keys (same topology at every pose)."""
    parts = [o for o in bpy.context.scene.objects if o.type in ("MESH", "CURVE") and not o.hide_render]

    def poses_pos(p, kind="roar"):
        (lion.roar if kind == "roar" else lion.idle)(p)
        bpy.context.view_layer.update()
        dg = bpy.context.evaluated_depsgraph_get()
        return [_eval_part(ob, dg) for ob in parts]

    base = poses_pos(POSE_KEYS[0])
    verts, faces, mat_of_face, g, rnd = [], [], [], [], []
    mats = []
    for ob, (world, local, fcs) in zip(parts, base):
        m = ob.data.materials[0]
        if m not in mats:
            mats.append(m)
        mi = mats.index(m)
        off = len(verts)
        verts += world
        faces += [tuple(i + off for i in f) for f in fcs]
        mat_of_face += [mi] * len(fcs)
        kind = ob.get("gk", "")
        xs, ys, zs = [c[0] for c in local], [c[1] for c in local], [c[2] for c in local]
        lo = (min(xs), min(ys), min(zs))
        sz = (max(xs) - lo[0] or 1.0, max(ys) - lo[1] or 1.0, max(zs) - lo[2] or 1.0)
        for c in local:
            gx, gy, gz = (c[0] - lo[0]) / sz[0], (c[1] - lo[1]) / sz[1], (c[2] - lo[2]) / sz[2]
            if kind == "mouth":
                g.append(math.sqrt((gx - 0.5) ** 2 + (gy - 0.5) ** 2 + (gz - 0.42) ** 2))
            elif kind == "tongue":
                g.append(gy)
            else:
                g.append(0.0)
            rnd.append(float(ob.get("rnd", 0.0)))

    me = bpy.data.meshes.new("joker_lion")
    me.from_pydata(verts, [], faces)
    me.update()
    for m in mats:
        me.materials.append(m)
    me.polygons.foreach_set("material_index", mat_of_face)
    me.polygons.foreach_set("use_smooth", [True] * len(me.polygons))
    for name, vals in (("g", g), ("rnd", rnd)):
        at = me.attributes.new(name, "FLOAT", "POINT")
        at.data.foreach_set("value", vals)
    final = bpy.data.objects.new("joker_lion", me)
    bpy.context.collection.objects.link(final)
    final.shape_key_add(name="Basis")
    for i, p in enumerate(POSE_KEYS[1:], start=1):
        pos = poses_pos(p)
        flat = []
        for (world, _l, _f) in pos:
            for c in world:
                flat += c
        assert len(flat) == len(verts) * 3, "topology changed between poses"
        sk = final.shape_key_add(name="p%02d" % i, from_mix=False)
        sk.data.foreach_set("co", flat)
    for i, p in enumerate(IDLE_KEYS, start=1):
        pos = poses_pos(p, "idle")
        flat = []
        for (world, _l, _f) in pos:
            for c in world:
                flat += c
        assert len(flat) == len(verts) * 3, "topology changed between poses"
        sk = final.shape_key_add(name="i%02d" % i, from_mix=False)
        sk.data.foreach_set("co", flat)
    # drop every original part: only the single mesh remains
    for ob in list(bpy.data.objects):
        if ob is not final and ob.type in ("MESH", "CURVE", "EMPTY"):
            bpy.data.objects.remove(ob, do_unlink=True)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    print("SINGLE MESH: %d mesh object(s), %d verts, %d faces, %d materials, %d shape keys" % (
        len(meshes), len(me.vertices), len(me.polygons), len(me.materials), len(final.data.shape_keys.key_blocks)))
    assert len(meshes) == 1
    return final


def set_pose(final, p, kind="roar"):
    """Blend the two neighbouring shape keys. kind 'roar' uses p00.., 'idle' (periodic) uses i01.."""
    kb = final.data.shape_keys.key_blocks
    for k in kb[1:]:
        k.value = 0.0
    p = clamp01(p)
    if kind == "roar":
        j = 0
        while j < len(POSE_KEYS) - 2 and p > POSE_KEYS[j + 1]:
            j += 1
        t = (p - POSE_KEYS[j]) / (POSE_KEYS[j + 1] - POSE_KEYS[j])
        if j > 0:
            kb["p%02d" % j].value = 1.0 - t
        kb["p%02d" % (j + 1)].value = t
    else:
        x = p * IDLE_N
        j = min(int(x), IDLE_N - 1)
        t = x - j
        if j >= 1:
            kb["i%02d" % j].value = 1.0 - t
        if j + 1 <= IDLE_N - 1:
            kb["i%02d" % (j + 1)].value = t


def main():
    o = args()
    os.makedirs(o["out"], exist_ok=True)
    reset_scene()
    scene = bpy.context.scene
    setup_render(scene, o["size"])
    setup_world(scene)
    setup_camera(scene)
    add_area_light("key", (-3.0, -5.0, 4.0), 6.0, 400)
    add_area_light("fill", (3.5, -5.0, -1.0), 6.0, 110, (1.0, 0.97, 0.92))
    # rim lights from behind pick out the mane's edge
    add_area_light("rimL", (-4.0, 4.0, 3.0), 4.0, 420, (1.0, 0.95, 0.9))
    add_area_light("rimR", (4.0, 4.0, 3.0), 4.0, 420, (1.0, 0.95, 0.9))
    add_area_light("rimB", (0.0, 4.0, -4.0), 4.0, 260, (1.0, 0.9, 0.85))
    lion = Lion(o["color"])
    final = bake_single_mesh(lion)

    kind = "idle" if o["mode"] == "idle" else "roar"

    def shot(path, p):
        set_pose(final, p, kind)
        scene.render.filepath = path
        bpy.ops.render.render(write_still=True)

    if o["mode"] == "still":
        shot(os.path.join(o["out"], "_still_%s.png" % o["color"]), 0.0)
    elif o["mode"] == "idle":
        d = os.path.join(o["out"], o["color"] + "_idle")
        os.makedirs(d, exist_ok=True)
        n = o["frames"]
        for f in range(n):
            shot(os.path.join(d, "f%02d.png" % f), f / n)
    elif o["mode"] == "poses":
        for i, p in enumerate(o["plist"]):
            shot(os.path.join(o["out"], "pose_%s_%d.png" % (o["color"], i)), p)
    else:
        d = os.path.join(o["out"], o["color"])
        os.makedirs(d, exist_ok=True)
        n = o["frames"]
        for f in range(n):
            shot(os.path.join(d, "f%02d.png" % f), f / n)


main()
