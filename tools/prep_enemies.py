"""Shrinks the downloaded enemy bodies for mobile: decimates the skinned meshes and downsizes their textures.

Usage:  blender -b --python tools/prep_enemies.py -- <in.glb|gltf> <out.glb> <triangle budget> <texture size>
Weights and bone names are kept, so the figure code (models.gd) drives the result like the original.
"""
import sys

import bpy

src, dst, budget, tex = sys.argv[sys.argv.index("--") + 1:][:4]
budget = int(budget)
tex = int(tex)
bpy.ops.wm.read_factory_settings(use_empty=True)
if src.endswith(".gltf") or src.endswith(".glb"):
    bpy.ops.import_scene.gltf(filepath=src)
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
total = 0
for o in meshes:
    o.data.calc_loop_triangles()
    total += len(o.data.loop_triangles)
ratio = min(1.0, budget / max(total, 1))
print("TRIS before", total, "ratio", ratio)
for o in meshes:
    o.data.calc_loop_triangles()
    if len(o.data.loop_triangles) < 1500:
        continue
    bpy.context.view_layer.objects.active = o
    md = o.modifiers.new("dec", "DECIMATE")
    md.ratio = ratio
    md.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=md.name)
after = 0
for o in meshes:
    o.data.calc_loop_triangles()
    after += len(o.data.loop_triangles)
print("TRIS after", after)
for img in bpy.data.images:
    if img.size[0] > tex or img.size[1] > tex:
        img.scale(tex, tex)
bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB", export_animations=False, export_skins=True, export_image_format="JPEG", export_jpeg_quality=88)
