"""Builds the civilians' bodies for the game: a Quaternius Peasant outfit (CC0) worn by the matching base character, merged onto ONE skeleton.

Usage:  blender -b --python tools/prep_civilians.py -- <dir with Male_Peasant.gltf, Female_Peasant.gltf, the two Superhero_*_FullBody.gltf> <out dir>
The base body keeps only its head, neck and hands (the outfit covers the rest), the outfit is decimated, textures are shrunk to 1024.
"""
import os
import sys

import bpy
import bmesh

src, out = sys.argv[sys.argv.index("--") + 1:][:2]
os.makedirs(out, exist_ok=True)
KEEP = ("Head", "head", "neck", "hand", "index", "middle", "ring", "pinky", "thumb")
BUDGET = 5200


def import_gltf(name):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(src, name))
    return [o for o in bpy.data.objects if o not in before]


def build(gender, outfit, base):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    out_objs = import_gltf(outfit)
    base_objs = import_gltf(base)
    arm_out = next(o for o in out_objs if o.type == "ARMATURE")
    arm_base = next(o for o in base_objs if o.type == "ARMATURE")
    base_meshes = [o for o in base_objs if o.type == "MESH"]
    # keep only head / neck / hands of the base body
    for m in base_meshes:
        if len(m.data.vertices) < 3000:
            continue
        bm = bmesh.new()
        bm.from_mesh(m.data)
        deform = bm.verts.layers.deform.active
        drop = []
        for v in bm.verts:
            best = None
            bw = -1.0
            for gi, w in v[deform].items():
                if w > bw:
                    bw = w
                    best = m.vertex_groups[gi].name
            if best is None or not best.startswith(KEEP):
                drop.append(v)
        bmesh.ops.delete(bm, geom=drop, context="VERTS")
        bm.to_mesh(m.data)
        bm.free()
    # put the base meshes on the outfit's skeleton
    for m in base_meshes:
        for mod in m.modifiers:
            if mod.type == "ARMATURE":
                mod.object = arm_out
        m.parent = arm_out
        m.matrix_parent_inverse = arm_out.matrix_world.inverted()
    bpy.data.objects.remove(arm_base, do_unlink=True)
    # decimate the outfit
    out_meshes = [o for o in out_objs if o.type == "MESH"]
    tris = 0
    for o in out_meshes:
        o.data.calc_loop_triangles()
        tris += len(o.data.loop_triangles)
    ratio = min(1.0, BUDGET / max(tris, 1))
    for o in out_meshes:
        bpy.context.view_layer.objects.active = o
        md = o.modifiers.new("dec", "DECIMATE")
        md.ratio = ratio
        md.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier=md.name)
    for img in bpy.data.images:
        if img.size[0] > 1024 or img.size[1] > 1024:
            img.scale(1024, 1024)
    # the peasants' ORM / normal maps are not worth the memory on a phone
    for mat in bpy.data.materials:
        if mat.use_nodes:
            for node in list(mat.node_tree.nodes):
                if node.type == "TEX_IMAGE" and node.image is not None and ("Normal" in node.image.name or "ORM" in node.image.name or "Roughness" in node.image.name):
                    mat.node_tree.nodes.remove(node)
    bpy.ops.export_scene.gltf(filepath=os.path.join(out, "Civ_%s.glb" % gender), export_format="GLB", export_animations=False, export_skins=True,
        export_image_format="JPEG", export_jpeg_quality=86)
    print("DONE", gender, "outfit tris after", sum(len(o.data.loop_triangles) for o in out_meshes if o.data.calc_loop_triangles() is None))


build("M", "Male_Peasant.gltf", "Superhero_Male_FullBody.gltf")
build("F", "Female_Peasant.gltf", "Superhero_Female_FullBody.gltf")
