"""Shrinks the Poly Haven models for mobile: Blender decimates every mesh to a triangle budget and downsizes textures.

Usage (Blender 4/5):
    blender -b --python tools/decimate_models.py -- <models_dir> <out_dir>
It reads  <models_dir>/<id>/<id>_1k.gltf  and writes  <out_dir>/<id>/<id>_1k.gltf (+ .bin and textures/), keeping node and mesh names,
so game code that looks nodes up by name (for example the chest lid) keeps working.
"""
import os
import sys

import bpy

models_dir, out_dir = sys.argv[sys.argv.index("--") + 1:][:2]
TEX = 512
JPEG_Q = 88

# triangle budget per model (all meshes of the model together)
BUDGET = {
    "boulder_01": 2500, "dead_tree_trunk": 2500, "dead_tree_trunk_02": 2500, "tree_stump_01": 1500,
    "treasure_chest": 5000, "wooden_barrels_01": 4500, "wicker_basket_01": 1500, "wooden_crate_01": 2500,
    "wooden_crate_02": 2200, "wooden_bucket_01": 1500, "wooden_lantern_01": 2000, "vintage_oil_lamp": 2000,
    "stone_fire_pit": 2000, "hatchet": 1500, "wooden_axe_03": 1500, "antique_estoc": 3000, "ornate_war_hammer": 2500,
    "ornate_medieval_mace": 3000, "service_pistol": 3000, "kite_shield": 4000,
}


def tri_count(obj):
    obj.data.calc_loop_triangles()
    return len(obj.data.loop_triangles)


def process(model_id, budget):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    src = os.path.join(models_dir, model_id, model_id + "_1k.gltf")
    bpy.ops.import_scene.gltf(filepath=src)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    total = sum(tri_count(o) for o in meshes)
    ratio = min(1.0, budget / max(total, 1))
    for o in meshes:
        n = tri_count(o)
        # tiny parts (handles, locks) keep a minimum so they stay recognisable
        r = max(ratio, min(1.0, 120.0 / max(n, 1)))
        if r >= 0.999:
            continue
        bpy.context.view_layer.objects.active = o
        o.select_set(True)
        mod = o.modifiers.new("dec", "DECIMATE")
        mod.ratio = r
        mod.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier="dec")
        o.select_set(False)
    after = sum(tri_count(o) for o in meshes)
    # stubborn meshes (disconnected pieces) can stop short of the target: run extra passes
    for _ in range(3):
        if after <= budget * 1.3:
            break
        r2 = budget / after
        for o in meshes:
            n = tri_count(o)
            if n < 200:
                continue
            bpy.context.view_layer.objects.active = o
            o.select_set(True)
            # photogrammetry meshes are often split along every UV seam, which blocks edge collapse: weld them first
            bpy.ops.object.mode_set(mode="EDIT")
            bpy.ops.mesh.select_all(action="SELECT")
            bpy.ops.mesh.remove_doubles(threshold=0.003)
            bpy.ops.object.mode_set(mode="OBJECT")
            mod = o.modifiers.new("dec2", "DECIMATE")
            mod.ratio = max(r2, 0.02)
            mod.use_collapse_triangulate = True
            bpy.ops.object.modifier_apply(modifier="dec2")
            o.select_set(False)
        after = sum(tri_count(o) for o in meshes)
    for img in list(bpy.data.images):
        if img.name == "Render Result" or img.size[0] == 0:
            continue
        w, h = img.size
        if max(w, h) > TEX:
            k = TEX / max(w, h)
            img.scale(max(1, int(w * k)), max(1, int(h * k)))
        img.pack()
    out = os.path.join(out_dir, model_id)
    os.makedirs(out, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=os.path.join(out, model_id + "_1k.gltf"), export_format="GLTF_SEPARATE",
        export_image_format="JPEG", export_jpeg_quality=JPEG_Q, export_texture_dir="textures", export_yup=True)
    print("DECIMATED %-22s %7d -> %6d tris" % (model_id, total, after))


for mid, bud in BUDGET.items():
    process(mid, bud)
