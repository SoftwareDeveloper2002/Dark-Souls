"""Exports the Godot Terrain3D regions (demo/data/terrain3d_*.res) as an Unreal Landscape heightmap (.r16)
and the quest route (scripts/world.gd) as a C++ include. Needs Python 3.14+ (compression.zstd).

Usage:  python unreal/tools/export_terrain.py
"""
import array, math, os, re, struct, sys
from compression import zstd

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "unreal", "DarkSouls")
REGION = 1024                       # Terrain3D region size (vertices == metres)
REGIONS = {-2: "terrain3d_00-02.res", -1: "terrain3d_00-01.res", 0: "terrain3d_00_00.res"}  # region z index -> file
LAND_W, LAND_H = 1009, 3025         # valid Unreal landscape sizes (63 quads * 16 / 48 components + 1)


def load_heights(fn):
    b = open(os.path.join(ROOT, "demo", "data", fn), "rb").read()
    _, bs, total = struct.unpack("<III", b[4:16])
    n = (total + bs - 1) // bs
    sizes = struct.unpack("<%dI" % n, b[16:16 + 4 * n])
    off, out = 16 + 4 * n, bytearray()
    for s in sizes:
        out += zstd.decompress(b[off:off + s])
        off += s
    a = array.array("f")
    a.frombytes(bytes(out[578:578 + REGION * REGION * 4]))  # first PackedByteArray in the region = height map
    return a


def smoothstep(a, b, x):
    t = min(max((x - a) / (b - a), 0.0), 1.0)
    return t * t * (3.0 - 2.0 * t)


def quest_sites(n_route, clear):
    """Port of World._build(): route index of each of the 40 quest sites."""
    first, gap, tunnel = 18, 3, 11
    last = n_route - 1 - gap - tunnel
    out = []
    for i in range(40):
        nominal = first + int(round(i * (last - first) / 39.0))
        if i >= 10:
            nominal += tunnel
        pick = nominal
        if (i + 1) % 10 == 0 and i < 39:
            best, lo, hi = -1, nominal - 7, nominal + 8
            if i == 9:
                hi = nominal + 1
            for k in range(lo, hi):
                if 0 < k < n_route and clear[k] > best:
                    best, pick = clear[k], k
        out.append(pick)
    return out


def bake_terrain_edits(height, full_h, pts, clear):
    """The Godot game edits the terrain while you play (boss arenas, labyrinth floor, bridge chasm). Unreal cannot edit a
    Landscape at runtime, so the same edits are baked into the exported heightmap."""
    def idx(x, z):
        c, r = int(x), int(z) + 2048
        return r * REGION + c if 0 <= c < REGION and 0 <= r < full_h else -1

    def get(x, z):
        i = idx(x, z)
        return height[i] if i >= 0 else 0.0

    def put(x, z, v):
        i = idx(x, z)
        if i >= 0 and height[i] != 0.0:
            height[i] = v

    sites = quest_sites(len(pts), clear)
    P = lambda i: (float(pts[i][0]), float(pts[i][1]))

    def flatten_disc(c, flat_r, blend_r):
        base = get(c[0], c[1]); r_all = flat_r + blend_r
        for xi in range(int(c[0] - r_all), int(c[0] + r_all) + 1):
            for zi in range(int(c[1] - r_all), int(c[1] + r_all) + 1):
                d = math.hypot(xi - c[0], zi - c[1])
                h = get(xi, zi)
                if d > r_all or h == 0.0:
                    continue
                put(xi, zi, base + (h - base) * smoothstep(flat_r, r_all, d))

    def flatten_square(c, half, blend):
        base = get(c[0], c[1]); reach = half + blend
        for xi in range(int(c[0] - reach), int(c[0] + reach) + 1):
            for zi in range(int(c[1] - reach), int(c[1] + reach) + 1):
                edge = max(abs(xi - c[0]), abs(zi - c[1]))
                h = get(xi, zi)
                if h == 0.0:
                    continue
                put(xi, zi, base if edge <= half else base + (h - base) * smoothstep(half, reach, edge))

    for q in (10, 20):
        flatten_disc(P(sites[q - 1]), 30.0, 26.0)
    flatten_square(P(sites[26]), 15 * 6.0 * 0.5 + 4.0, 12.0)        # labyrinth, quest 27
    # bridge, quest 30
    ci = sites[29]
    c = P(ci)
    a, b = P(max(ci - 2, 0)), P(min(ci + 2, len(pts) - 1))
    dl = math.hypot(b[0] - a[0], b[1] - a[1]); d = ((b[0] - a[0]) / dl, (b[1] - a[1]) / dl); n = (-d[1], d[0])
    base = get(c[0], c[1]); half_len = 22.0; R = 64
    for xi in range(int(c[0] - R), int(c[0] + R) + 1):
        for zi in range(int(c[1] - R), int(c[1] + R) + 1):
            rel = (xi - c[0], zi - c[1]); rl = math.hypot(*rel)
            h0 = get(xi, zi)
            if rl > R or h0 == 0.0:
                continue
            lon = rel[0] * d[0] + rel[1] * d[1]; lat = rel[0] * n[0] + rel[1] * n[1]
            level = base
            if abs(lat) > 9.0 or abs(lon) > half_len + 6.0:
                lvl_t = smoothstep(half_len + 4.0, half_len + 22.0, max(abs(lon), abs(lat) * 1.6))
                level = base + (h0 - base) * lvl_t
            chasm = (1.0 - smoothstep(half_len - 1.2, half_len - 0.2, abs(lon))) * (1.0 - smoothstep(16.0, 26.0, abs(lat)))
            target = level + (base - 38.0 - level) * chasm
            w = smoothstep(R - 14.0, R - 1.0, rl)
            put(xi, zi, target + (h0 - target) * w)
    flatten_disc(P(sites[39]), 30.0, 26.0)                           # quest 40 arena


def main():
    full_h = REGION * len(REGIONS)
    height = array.array("f", [0.0]) * (REGION * full_h)    # row = world z (from -2048), column = world x (from 0)
    for zi, fn in REGIONS.items():
        a = load_heights(fn)
        row0 = (zi + 2) * REGION
        height[row0 * REGION:(row0 + REGION) * REGION] = a
    src = open(os.path.join(ROOT, "scripts", "world.gd")).read()
    pts = [(int(a), int(b)) for a, b in re.findall(r"Vector2\((-?\d+), (-?\d+)\)", src.split("static var CLEAR")[0])]
    clear = [int(c) for c in re.search(r"CLEAR := PackedInt32Array\(\[(.*?)\]\)", src, re.S).group(1).replace(chr(10), " ").split(",")]
    bake_terrain_edits(height, full_h, pts, clear)
    vals = [v for v in height if v != 0.0]
    lo, hi = min(vals), max(vals)
    print("height range %.1f .. %.1f m" % (lo, hi))

    def at(x, z):  # metres, world coordinates
        c = min(max(x, 0.0), REGION - 1.001)
        r = min(max(z + 2048.0, 0.0), full_h - 1.001)
        x0, z0 = int(c), int(r)
        fx, fz = c - x0, r - z0
        def g(xx, zz):
            v = height[zz * REGION + xx]
            return lo if v == 0.0 else v
        return (g(x0, z0) * (1 - fx) + g(x0 + 1, z0) * fx) * (1 - fz) + (g(x0, z0 + 1) * (1 - fx) + g(x0 + 1, z0 + 1) * fx) * fz

    # Unreal 16 bit: world cm = (v - 32768) / 128 * ZScale. Pick ZScale so the whole range fits around 0.
    zscale = math.ceil(max(abs(lo), abs(hi)) * 100.0 / 256.0 * 1.02 / 10.0) * 10.0  # cm per 256 raw units... see README
    raw = bytearray()
    for j in range(LAND_H):
        z = -2048.0 + j * (REGION * 3.0) / (LAND_H - 1)
        for i in range(LAND_W):
            x = i * (REGION * 1.0) / (LAND_W - 1)
            h_cm = at(x, z) * 100.0
            v = int(round(32768 + h_cm * 128.0 / zscale))
            raw += struct.pack("<H", min(max(v, 0), 65535))
    os.makedirs(os.path.join(OUT, "Content", "ImportSource"), exist_ok=True)
    with open(os.path.join(OUT, "Content", "ImportSource", "dark_souls_heightmap_%dx%d.r16" % (LAND_W, LAND_H)), "wb") as f:
        f.write(raw)
    print("zscale", zscale)
    open(os.path.join(OUT, "Content", "ImportSource", "LANDSCAPE_IMPORT.txt"), "w").write(
        "Landscape > Import from File\n"
        "  Heightmap file : dark_souls_heightmap_%dx%d.r16 (16-bit little endian)\n"
        "  Resolution     : %d x %d  (63 quads/section, 1 section/component)\n"
        "  Location       : X=0, Y=-204800, Z=0   (so world metres match the Godot map: x 0..1024, z -2048..1024)\n"
        "  Scale          : X=%.4f, Y=%.4f, Z=%.4f\n"
        "Heights are in metres in the game's coordinates; ground level 0 = Godot y 0.\n" % (
            LAND_W, LAND_H, LAND_W, LAND_H, REGION * 100.0 / (LAND_W - 1), REGION * 3 * 100.0 / (LAND_H - 1), zscale))

    # route + clearing widths (parsed above)
    pts = [(str(x), str(y)) for x, y in pts]
    assert len(pts) == len(clear), (len(pts), len(clear))
    with open(os.path.join(OUT, "Source", "DarkSouls", "DSRoute.inc"), "w") as f:
        f.write("// Generated by unreal/tools/export_terrain.py from scripts/world.gd. Metres, (x, z) of the Godot map.\n")
        f.write("static const double GRouteXY[][2] = {\n")
        for i in range(0, len(pts), 8):
            f.write("\t" + ", ".join("{%s, %s}" % p for p in pts[i:i + 8]) + ",\n")
        f.write("};\nstatic const int32 GRouteClear[] = {\n")
        for i in range(0, len(clear), 24):
            f.write("\t" + ", ".join(str(c) for c in clear[i:i + 24]) + ",\n")
        f.write("};\n")
    print("route points", len(pts))
    # sanity check: ground height along the route should be smooth
    prev = None; worst = 0.0
    for (x, z) in pts:
        h = at(float(x), float(z))
        if prev is not None:
            worst = max(worst, abs(h - prev))
        prev = h
    print("largest step between route points: %.1f m" % worst)


main()
