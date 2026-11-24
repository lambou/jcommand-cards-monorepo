"""Renders the avatar frame (the ring around a player's portrait) to transparent PNGs (run inside Blender, headless).

  blender -b -P tools/avatars/render_frame.py -- [--size 512] [--out apps/mobile/assets/avatars]

Output: frame_thin.png / frame_thick.png. Neutral silver, lit like a polished bevelled metal band; the game tints
them with a modulate colour (gold for the active player, white for the rest), so the highlights stay bright and
the shadows pick up the tint. The ring centre line sits at radius 1.0 and the image spans +-1.1, so the game
draws it into a square of side 2.2 * avatar radius centred on the avatar.
"""
import bpy, math, sys, os
from mathutils import Vector

ROOT = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(ROOT, "..", ".."))
VARIANTS = {"thin": 0.05, "thick": 0.085}   # half-width of the band, in avatar radii
SPAN = 2.2


def args():
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    o = {"size": 512, "out": os.path.join(REPO, "apps", "mobile", "assets", "avatars")}
    for i, k in enumerate(a):
        if k == "--size":
            o["size"] = int(a[i + 1])
        elif k == "--out":
            o["out"] = a[i + 1]
    return o


def build(half):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    # Band: a torus squashed in Z gives a rounded, bevelled profile that catches light on both edges.
    bpy.ops.mesh.primitive_torus_add(major_radius=1.0, minor_radius=half, major_segments=192, minor_segments=48)
    band = bpy.context.object
    band.scale.z = 0.7
    bpy.ops.object.shade_smooth()
    # Thin bright lip on the inside edge, so the ring reads as a frame holding the portrait.
    bpy.ops.mesh.primitive_torus_add(major_radius=1.0 - half * 0.78, minor_radius=half * 0.22, major_segments=192, minor_segments=24)
    lip = bpy.context.object
    lip.location.z = half * 0.18
    bpy.ops.object.shade_smooth()

    m = bpy.data.materials.new("metal")
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (0.92, 0.92, 0.95, 1)
    b.inputs["Metallic"].default_value = 1.0
    b.inputs["Roughness"].default_value = 0.3
    for o in (band, lip):
        o.data.materials.append(m)

    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = SPAN
    cam.location = (0, 0, 6)
    sc.camera = cam

    # Soft studio: key from the top-left, fill from the lower right, plus a bright sky so the metal has something to reflect.
    for name, loc, energy, size in (("key", (-3.0, 3.0, 2.0), 600, 2.5), ("rim", (3.0, -3.0, 1.2), 260, 1.5), ("top", (0, 0, 5), 40, 4.0)):
        L = bpy.data.objects.new(name, bpy.data.lights.new(name, "AREA"))
        sc.collection.objects.link(L)
        L.location = loc
        L.data.energy = energy
        L.data.size = size
        d = Vector((0, 0, 0)) - Vector(loc)
        L.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    w = bpy.data.worlds.new("w")
    sc.world = w
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs["Color"].default_value = (0.30, 0.31, 0.35, 1)
    w.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.5


def main():
    o = args()
    os.makedirs(o["out"], exist_ok=True)
    for name, half in VARIANTS.items():
        build(half)
        sc = bpy.context.scene
        sc.render.engine = "CYCLES"
        sc.cycles.samples = 96
        sc.cycles.use_denoising = True
        sc.render.resolution_x = sc.render.resolution_y = o["size"]
        sc.render.resolution_percentage = 100
        sc.render.film_transparent = True
        sc.render.image_settings.file_format = "PNG"
        sc.render.image_settings.color_mode = "RGBA"
        sc.view_settings.view_transform = "Standard"
        sc.render.filepath = os.path.join(o["out"], "frame_%s.png" % name)
        bpy.ops.render.render(write_still=True)
        print("wrote", sc.render.filepath)


main()
