"""Glossy cartoon gold crown, hollow/open through the middle (no cap).
  blender -b -P tools/blender/make_crown.py -- <out_dir> [--frames N] [--size PX]
With --frames N it renders a seamless N-frame loop (sway, bob, sweeping highlight) into <out_dir>/frames/fNN.png;
pack_crown.py turns that into the game's spritesheet. Without it, writes crown.blend, crown.glb, crown.png (transparent preview) into out_dir."""
import bpy, bmesh, math, sys, os
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else ["."]
out = args[0]
FRAMES = int(args[args.index("--frames") + 1]) if "--frames" in args else 0
SIZE = int(args[args.index("--size") + 1]) if "--size" in args else 512
os.makedirs(out, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)

def mat(name, color, rough, metal=0.55, emit=0.0):
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = color
    b.inputs["Metallic"].default_value = metal
    b.inputs["Roughness"].default_value = rough
    if emit:
        b.inputs["Emission Color"].default_value = color
        b.inputs["Emission Strength"].default_value = emit
    return m
gold = mat("Gold", (0.95, 0.58, 0.08, 1), 0.25, 0.6, 0.0)
rim_m = mat("Rim", (0.8, 0.42, 0.04, 1), 0.25, 0.6, 0.0)

R_BOT, R_TOP = 1.0, 0.82
H_BASE = 0.3
PEAKS = 5
peak_h = [1.6, 1.15, 1.15, 1.15, 1.15]   # index 0 = front, tallest
SEG = 160

def height(t):
    # triangle wave between peaks: sharp V valleys, rounded later by subsurf
    k = (t / (2 * math.pi)) * PEAKS
    i = int(round(k)) % PEAKS
    d = abs(k - round(k))            # 0 at peak, .5 at valley
    return 0.5 + (peak_h[i] * 0.75 - 0.5) * (1 - d * 2) ** 0.55

# wall: open tube whose top edge follows the peak profile, flaring at the base
bm = bmesh.new()
rows = 6
grid = []
for r in range(rows + 1):
    row = []
    for s in range(SEG):
        t = s * 2 * math.pi / SEG
        top = H_BASE + height(t)
        f = r / rows
        z = f * top
        rad = R_BOT + (R_TOP - R_BOT) * (z / 1.6)
        row.append(bm.verts.new((math.cos(t) * rad, math.sin(t) * rad, z)))
    grid.append(row)
for r in range(rows):
    for s in range(SEG):
        bm.faces.new((grid[r][s], grid[r][(s + 1) % SEG], grid[r + 1][(s + 1) % SEG], grid[r + 1][s]))
me = bpy.data.meshes.new("Wall"); bm.to_mesh(me); bm.free()
wall = bpy.data.objects.new("Wall", me); bpy.context.collection.objects.link(wall)
bpy.context.view_layer.objects.active = wall
sol = wall.modifiers.new("Solid", 'SOLIDIFY'); sol.thickness = 0.12; sol.offset = 0
sub = wall.modifiers.new("Sub", 'SUBSURF'); sub.levels = 2; sub.render_levels = 2
wall.data.materials.append(gold)
for p in wall.data.polygons: p.use_smooth = True

# thick rounded rim at the bottom (hollow ring => the hole)
bpy.ops.mesh.primitive_torus_add(major_radius=R_BOT, minor_radius=0.13,
                                 major_segments=96, minor_segments=24, location=(0, 0, 0.05))
rim = bpy.context.object; rim.scale.z = 0.8
rim.data.materials.append(rim_m)
for p in rim.data.polygons: p.use_smooth = True
# raised band bead just above the rim
bpy.ops.mesh.primitive_torus_add(major_radius=R_BOT - 0.03, minor_radius=0.07,
                                 major_segments=96, minor_segments=16, location=(0, 0, 0.3))
bead = bpy.context.object; bead.data.materials.append(gold)
for p in bead.data.polygons: p.use_smooth = True

# big ball on each peak
for i in range(PEAKS):
    t = i * 2 * math.pi / PEAKS - math.pi / 2          # peak 0 faces the camera (-Y)
    top = H_BASE + 0.5 + (peak_h[i] * 0.75 - 0.5)
    rad = R_BOT + (R_TOP - R_BOT) * (top / 1.6)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.2 if i == 0 else 0.17, segments=48, ring_count=24,
                                         location=(math.cos(t) * rad, math.sin(t) * rad, top + 0.05))
    b = bpy.context.object; b.data.materials.append(gold)
    for p in b.data.polygons: p.use_smooth = True
# the profile above is built around +X as peak 0; rotate whole wall so peak 0 matches the ball
wall.rotation_euler.z = -math.pi / 2

# camera: front, slightly above so the opening is visible; transparent background
sc = bpy.context.scene
w = bpy.data.worlds.new("W"); w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.07, 0.33, 0.21, 1)
w.node_tree.nodes["Background"].inputs[1].default_value = 1.0
sc.world = w
for loc, e in (((-3, -4, 6), 600), ((4, -3, 2), 200), ((0, 5, 4), 400)):
    bpy.ops.object.light_add(type='AREA', location=loc)
    l = bpy.context.object; l.data.energy = e; l.data.size = 3
    l.rotation_euler = (Vector((0, 0, 0.6)) - l.location).to_track_quat('-Z', 'Y').to_euler()
bpy.ops.object.camera_add(location=(0, -3.6, 2.8))
cam = bpy.context.object
cam.rotation_euler = (Vector((0, 0, 0.7)) - cam.location).to_track_quat('-Z', 'Y').to_euler()
sc.camera = cam
sc.render.engine = 'CYCLES'; sc.cycles.samples = 96; sc.cycles.use_denoising = True
sc.render.film_transparent = True
sc.view_settings.view_transform = 'Standard'
sc.render.resolution_x = sc.render.resolution_y = SIZE
if FRAMES:
    pivot = bpy.data.objects.new("Pivot", None); bpy.context.collection.objects.link(pivot)
    for o in bpy.data.objects:
        if o.type == 'MESH': o.parent = pivot
    key = [o for o in bpy.data.objects if o.type == 'LIGHT'][0]
    key0 = key.location.copy()
    sc.cycles.samples = 48
    os.makedirs(os.path.join(out, "frames"), exist_ok=True)
    for i in range(FRAMES):
        ph = 2 * math.pi * i / FRAMES
        pivot.rotation_euler.z = math.radians(26) * math.sin(ph)        # sway left/right
        pivot.rotation_euler.x = math.radians(3) * math.sin(ph * 2)     # tiny nod
        pivot.location.z = 0.06 * math.sin(ph * 2)                      # bob
        key.location.x = key0.x + 4.0 * math.sin(ph)                    # highlight sweeps across the gold
        sc.render.filepath = os.path.join(out, "frames", "f%02d.png" % i)
        bpy.ops.render.render(write_still=True)
    print("frames done", out)
    sys.exit(0)
sc.render.filepath = os.path.join(out, "crown.png")
bpy.ops.render.render(write_still=True)

for o in bpy.data.objects: o.select_set(o.type == 'MESH')
bpy.ops.export_scene.gltf(filepath=os.path.join(out, "crown.glb"), use_selection=True, export_apply=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out, "crown.blend"))
print("done", out)
