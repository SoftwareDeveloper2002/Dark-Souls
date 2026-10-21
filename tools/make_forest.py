"""Builds the forest set (pines, firs, dead trees, bushes, a fallen log) as low-poly glb files with real PBR bark and needle textures.

    blender -b --python tools/make_forest.py -- <texture_dir> <out_dir>

<texture_dir> must hold bark.jpg, bark_n.jpg, needles_a.jpg, needles_b.jpg, needles_n.jpg (prepared from Poly Haven pine_bark / leafy_grass, CC0).
Each live tree comes in three detail levels (name, name_lod1, name_lod2) so the game can swap by distance.
"""
import math
import os
import random
import sys

import bmesh
import bpy

tex_dir, out_dir = sys.argv[sys.argv.index("--") + 1:][:2]
os.makedirs(out_dir, exist_ok=True)


def image(name):
    return bpy.data.images.load(os.path.join(tex_dir, name))


def make_mat(name, albedo, normal, rough=0.85, uv_scale=1.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = rough
    t = nt.nodes.new("ShaderNodeTexImage")
    t.image = image(albedo)
    nt.links.new(t.outputs["Color"], bsdf.inputs["Base Color"])
    n = nt.nodes.new("ShaderNodeTexImage")
    n.image = image(normal)
    n.image.colorspace_settings.name = "Non-Color"
    nm = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(n.outputs["Color"], nm.inputs["Color"])
    nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    m.use_backface_culling = False
    return m


def new_obj(name, bm, mats):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    for m in mats:
        me.materials.append(m)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    # the geometry above is authored Y-up; Blender is Z-up, so stand it up before export
    ob.rotation_euler = (math.pi / 2, 0, 0)
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    ob.select_set(False)
    return ob


def add_tri(bm, a, b, c, uvs, mat_i):
    layer = bm.loops.layers.uv.verify()
    f = bm.faces.new((a, b, c))
    f.material_index = mat_i
    for lp, uv in zip(f.loops, uvs):
        lp[layer].uv = uv
    return f


def trunk(bm, rng, h, r0, sides, rings, lean, mat_i=0, top_r=0.04):
    verts = []
    for ri in range(rings + 1):
        t = ri / rings
        y = h * t
        r = r0 * (1 - t) ** 0.8 + top_r * (1 - t) + 0.01
        cx = lean * t * t * h * 0.1
        row = []
        for s in range(sides):
            a = s / sides * math.tau
            wob = 1.0 + rng.uniform(-0.08, 0.08)
            row.append(bm.verts.new((cx + math.cos(a) * r * wob, y, math.sin(a) * r * wob)))
        verts.append(row)
    for ri in range(rings):
        for s in range(sides):
            a, b = verts[ri][s], verts[ri][(s + 1) % sides]
            c, d = verts[ri + 1][(s + 1) % sides], verts[ri + 1][s]
            u0, u1 = s / sides * 2, (s + 1) / sides * 2
            v0, v1 = ri / rings * h * 0.4, (ri + 1) / rings * h * 0.4
            add_tri(bm, a, b, c, [(u0, v0), (u1, v0), (u1, v1)], mat_i)
            add_tri(bm, a, c, d, [(u0, v0), (u1, v1), (u0, v1)], mat_i)


def foliage(bm, rng, h, R, tiers, pts, droop, base, mat_i=1, top=0.97):
    """Layered skirts of star-shaped branch sprays; each tier is a cone with a ragged, drooping rim."""
    for ti in range(tiers):
        t = ti / max(tiers - 1, 1)
        y_base = h * (base + (top - base - 0.12) * t)
        tier_h = h * (0.26 - 0.1 * t)
        r_out = R * (1 - 0.88 * t) * rng.uniform(0.9, 1.1) + 0.12
        apex = bm.verts.new((rng.uniform(-0.04, 0.04) * R, y_base + tier_h, rng.uniform(-0.04, 0.04) * R))
        ring = []
        for k in range(pts * 2):
            ang = k / (pts * 2) * math.tau + rng.uniform(-0.12, 0.12)
            rad = r_out * (1.0 if k % 2 == 0 else 0.64) * rng.uniform(0.88, 1.1)
            drop = droop * r_out * (1.0 if k % 2 == 0 else 0.35) + rng.uniform(-0.05, 0.05)
            ring.append(bm.verts.new((math.cos(ang) * rad, y_base - drop, math.sin(ang) * rad)))
        low = bm.verts.new((0, y_base - 0.04, 0))
        n = len(ring)
        for k in range(n):
            a, b = ring[k], ring[(k + 1) % n]
            ua, ub = (a.co.x / (2 * R) + 0.5) * 3, (b.co.x / (2 * R) + 0.5) * 3
            va, vb = (a.co.z / (2 * R) + 0.5) * 3, (b.co.z / (2 * R) + 0.5) * 3
            add_tri(bm, apex, a, b, [(1.5, 1.5), (ua, va), (ub, vb)], mat_i)
            add_tri(bm, low, b, a, [(1.5, 1.5), (ub, vb), (ua, va)], mat_i)


def branch(bm, rng, base, dirv, length, r0, mat_i=0, sides=5, segs=3):
    prev = None
    pos = list(base)
    d = list(dirv)
    for si in range(segs + 1):
        t = si / segs
        r = r0 * (1 - t) + 0.006
        # ring perpendicular to the branch (approx): use two axes
        ax = (-d[2], 0, d[0])
        l = math.hypot(ax[0], ax[2]) or 1.0
        ax = (ax[0] / l, 0, ax[2] / l)
        ay = (d[1] * ax[2] * 0 + 0, 1, 0)
        row = []
        for s in range(sides):
            a = s / sides * math.tau
            row.append(bm.verts.new((pos[0] + ax[0] * math.cos(a) * r, pos[1] + math.sin(a) * r, pos[2] + ax[2] * math.cos(a) * r)))
        if prev:
            for s in range(sides):
                add_tri(bm, prev[s], prev[(s + 1) % sides], row[(s + 1) % sides], [(0, 0), (1, 0), (1, 1)], mat_i)
                add_tri(bm, prev[s], row[(s + 1) % sides], row[s], [(0, 0), (1, 1), (0, 1)], mat_i)
        prev = row
        step = length / segs
        d = [d[0] + rng.uniform(-0.25, 0.25), d[1] + rng.uniform(-0.1, 0.12), d[2] + rng.uniform(-0.25, 0.25)]
        n = math.sqrt(sum(c * c for c in d)) or 1
        d = [c / n for c in d]
        pos = [pos[0] + d[0] * step, pos[1] + d[1] * step, pos[2] + d[2] * step]


def live_tree(name, seed, h, R, tiers, pts, droop, sides, lean, bark_m, needle_m, base=0.2):
    rng = random.Random(seed)
    bm = bmesh.new()
    trunk(bm, rng, h * 0.9, h * 0.028, sides, 4, lean)
    foliage(bm, rng, h, R, tiers, pts, droop, base)
    return new_obj(name, bm, [bark_m, needle_m])


def dead_tree(name, seed, h, bark_m):
    rng = random.Random(seed)
    bm = bmesh.new()
    trunk(bm, rng, h, h * 0.03, 7, 6, rng.uniform(-1, 1), top_r=0.02)
    for i in range(7):
        y = h * rng.uniform(0.35, 0.92)
        a = rng.uniform(0, math.tau)
        d = (math.cos(a) * 0.9, rng.uniform(0.1, 0.55), math.sin(a) * 0.9)
        n = math.sqrt(sum(c * c for c in d))
        branch(bm, rng, (0, y, 0), [c / n for c in d], h * rng.uniform(0.18, 0.34) * (1.1 - y / h), h * 0.011, 0)
    return new_obj(name, bm, [bark_m])


def bush(name, seed, size, needle_m):
    rng = random.Random(seed)
    bm = bmesh.new()
    foliage(bm, rng, size, size * 0.55, 3, 7, 0.5, 0.0, mat_i=0, top=1.0)
    for i in range(2):
        pass
    return new_obj(name, bm, [needle_m])


def log(name, seed, length, r, bark_m):
    rng = random.Random(seed)
    bm = bmesh.new()
    sides, rings = 8, 4
    verts = []
    for ri in range(rings + 1):
        t = ri / rings
        x = (t - 0.5) * length
        rr = r * (1.0 - 0.12 * t)
        row = []
        for s in range(sides):
            a = s / sides * math.tau
            row.append(bm.verts.new((x, r + math.sin(a) * rr * rng.uniform(0.92, 1.05), math.cos(a) * rr * rng.uniform(0.92, 1.05))))
        verts.append(row)
    for ri in range(rings):
        for s in range(sides):
            a, b = verts[ri][s], verts[ri][(s + 1) % sides]
            c, d = verts[ri + 1][(s + 1) % sides], verts[ri + 1][s]
            u0, u1 = s / sides * 2, (s + 1) / sides * 2
            add_tri(bm, a, b, c, [(u0, ri), (u1, ri), (u1, ri + 1)], 0)
            add_tri(bm, a, c, d, [(u0, ri), (u1, ri + 1), (u0, ri + 1)], 0)
    return new_obj(name, bm, [bark_m])


def export(ob, name):
    for o in bpy.context.scene.objects:
        o.select_set(o == ob)
    bpy.context.view_layer.objects.active = ob
    path = os.path.join(out_dir, name + ".glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_image_format="JPEG", export_jpeg_quality=85, export_yup=True)
    tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
    print("EXPORT %-14s %5d tris  %5d KB" % (name, tris, os.path.getsize(path) // 1024))


bpy.ops.wm.read_factory_settings(use_empty=True)
bark = make_mat("bark", "bark.jpg", "bark_n.jpg", 0.9)
need_a = make_mat("needles_a", "needles_a.jpg", "needles_n.jpg", 0.8)
need_b = make_mat("needles_b", "needles_b.jpg", "needles_n.jpg", 0.8)

# (name, seed, height, radius, tiers, star points, droop, trunk sides, lean, needle material)
SPECS = [
    ("pine_1", 11, 13.0, 2.1, 9, 8, 0.28, 8, 0.4, need_a),
    ("pine_2", 23, 11.0, 2.4, 8, 8, 0.32, 8, -0.5, need_b),
    ("fir_1", 37, 9.5, 2.9, 9, 9, 0.38, 8, 0.2, need_b),
]
LOD = [("", 1.0), ("_lod1", 0.55), ("_lod2", 0.28)]
for nm, seed, h, R, tiers, pts, droop, sides, lean, nmat in SPECS:
    for suffix, k in LOD:
        t2 = max(3, int(round(tiers * (1.0 if k == 1.0 else (0.6 if k > 0.4 else 0.4)))))
        p2 = max(5, int(round(pts * (1.0 if k == 1.0 else (0.75 if k > 0.4 else 0.6)))))
        s2 = sides if k == 1.0 else (6 if k > 0.4 else 5)
        ob = live_tree(nm + suffix, seed, h, R, t2, p2, droop, s2, lean, bark, nmat)
        export(ob, nm + suffix)
export(dead_tree("dead_1", 51, 8.5, bark), "dead_1")
export(dead_tree("dead_2", 67, 6.5, bark), "dead_2")
export(bush("bush_1", 81, 1.2, need_a), "bush_1")
export(bush("bush_2", 97, 0.9, need_b), "bush_2")
export(log("log_1", 5, 3.4, 0.28, bark), "log_1")
