extends RefCounted
## The adventure map: a ~4 km road winding through the demo terrain's canyon,
## from the northern bowl (start) to the Dark Citadel basin (finale).
## ROUTE was computed offline by path-finding over walkable terrain; CLEAR is the open width (m) at each point.

static var ROUTE := PackedVector2Array([
	Vector2(220, -1836), Vector2(232, -1836), Vector2(244, -1840), Vector2(256, -1840), Vector2(268, -1840), Vector2(280, -1840),
	Vector2(292, -1844), Vector2(304, -1848), Vector2(316, -1848), Vector2(328, -1852), Vector2(340, -1856), Vector2(352, -1860),
	Vector2(364, -1860), Vector2(376, -1864), Vector2(388, -1868), Vector2(400, -1872), Vector2(412, -1872), Vector2(424, -1876),
	Vector2(436, -1876), Vector2(448, -1876), Vector2(460, -1880), Vector2(472, -1884), Vector2(484, -1888), Vector2(496, -1888),
	Vector2(508, -1892), Vector2(520, -1900), Vector2(532, -1900), Vector2(544, -1908), Vector2(556, -1908), Vector2(568, -1912),
	Vector2(580, -1912), Vector2(592, -1916), Vector2(604, -1916), Vector2(616, -1916), Vector2(628, -1916), Vector2(640, -1916),
	Vector2(652, -1916), Vector2(664, -1916), Vector2(676, -1912), Vector2(688, -1912), Vector2(700, -1908), Vector2(712, -1900),
	Vector2(724, -1900), Vector2(736, -1888), Vector2(744, -1876), Vector2(748, -1864), Vector2(748, -1852), Vector2(748, -1840),
	Vector2(744, -1828), Vector2(740, -1816), Vector2(732, -1804), Vector2(732, -1792), Vector2(732, -1780), Vector2(736, -1768),
	Vector2(740, -1756), Vector2(748, -1744), Vector2(748, -1732), Vector2(748, -1720), Vector2(748, -1708), Vector2(748, -1696),
	Vector2(748, -1684), Vector2(748, -1672), Vector2(748, -1660), Vector2(748, -1648), Vector2(748, -1636), Vector2(744, -1624),
	Vector2(732, -1612), Vector2(720, -1600), Vector2(712, -1588), Vector2(700, -1576), Vector2(688, -1568), Vector2(676, -1556),
	Vector2(664, -1548), Vector2(652, -1536), Vector2(640, -1528), Vector2(628, -1524), Vector2(616, -1516), Vector2(604, -1508),
	Vector2(592, -1504), Vector2(580, -1496), Vector2(568, -1488), Vector2(556, -1476), Vector2(544, -1464), Vector2(532, -1452),
	Vector2(520, -1440), Vector2(508, -1428), Vector2(496, -1416), Vector2(484, -1404), Vector2(476, -1392), Vector2(468, -1380),
	Vector2(460, -1368), Vector2(456, -1356), Vector2(448, -1344), Vector2(444, -1332), Vector2(436, -1320), Vector2(424, -1308),
	Vector2(420, -1296), Vector2(416, -1284), Vector2(412, -1272), Vector2(404, -1260), Vector2(392, -1248), Vector2(384, -1236),
	Vector2(380, -1224), Vector2(372, -1212), Vector2(368, -1200), Vector2(360, -1188), Vector2(352, -1176), Vector2(348, -1164),
	Vector2(344, -1152), Vector2(344, -1140), Vector2(344, -1128), Vector2(344, -1116), Vector2(344, -1104), Vector2(348, -1092),
	Vector2(348, -1080), Vector2(352, -1068), Vector2(352, -1056), Vector2(356, -1044), Vector2(356, -1032), Vector2(368, -1020),
	Vector2(380, -1008), Vector2(392, -996), Vector2(404, -984), Vector2(416, -976), Vector2(428, -964), Vector2(440, -960),
	Vector2(452, -948), Vector2(464, -944), Vector2(476, -932), Vector2(488, -920), Vector2(500, -908), Vector2(512, -896),
	Vector2(524, -884), Vector2(528, -872), Vector2(540, -860), Vector2(548, -848), Vector2(548, -836), Vector2(548, -824),
	Vector2(548, -812), Vector2(544, -800), Vector2(532, -788), Vector2(520, -776), Vector2(508, -764), Vector2(496, -752),
	Vector2(484, -740), Vector2(472, -736), Vector2(460, -732), Vector2(448, -728), Vector2(436, -724), Vector2(424, -720),
	Vector2(412, -720), Vector2(400, -716), Vector2(388, -708), Vector2(376, -700), Vector2(364, -688), Vector2(352, -676),
	Vector2(340, -664), Vector2(328, -652), Vector2(316, -640), Vector2(312, -628), Vector2(312, -616), Vector2(308, -604),
	Vector2(308, -592), Vector2(308, -580), Vector2(308, -568), Vector2(308, -556), Vector2(312, -544), Vector2(312, -532),
	Vector2(312, -520), Vector2(312, -508), Vector2(320, -496), Vector2(320, -484), Vector2(320, -472), Vector2(328, -460),
	Vector2(332, -448), Vector2(340, -436), Vector2(344, -424), Vector2(348, -412), Vector2(356, -400), Vector2(368, -388),
	Vector2(380, -376), Vector2(392, -372), Vector2(404, -364), Vector2(416, -356), Vector2(428, -352), Vector2(440, -344),
	Vector2(452, -336), Vector2(464, -328), Vector2(476, -324), Vector2(488, -320), Vector2(500, -320), Vector2(512, -316),
	Vector2(524, -316), Vector2(536, -316), Vector2(548, -316), Vector2(560, -316), Vector2(572, -316), Vector2(584, -316),
	Vector2(596, -316), Vector2(608, -316), Vector2(620, -316), Vector2(632, -316), Vector2(644, -316), Vector2(656, -312),
	Vector2(668, -304), Vector2(680, -304), Vector2(692, -300), Vector2(704, -300), Vector2(716, -292), Vector2(728, -284),
	Vector2(740, -272), Vector2(752, -260), Vector2(764, -252), Vector2(776, -244), Vector2(788, -232), Vector2(800, -220),
	Vector2(812, -208), Vector2(812, -196), Vector2(812, -184), Vector2(812, -172), Vector2(812, -160), Vector2(800, -148),
	Vector2(788, -136), Vector2(776, -124), Vector2(764, -124), Vector2(752, -124), Vector2(740, -124), Vector2(728, -124),
	Vector2(716, -124), Vector2(704, -124), Vector2(692, -124), Vector2(680, -124), Vector2(668, -120), Vector2(656, -120),
	Vector2(644, -112), Vector2(632, -104), Vector2(620, -100), Vector2(608, -100), Vector2(596, -92), Vector2(584, -80),
	Vector2(572, -80), Vector2(560, -80), Vector2(548, -72), Vector2(536, -68), Vector2(524, -68), Vector2(512, -64),
	Vector2(500, -64), Vector2(488, -60), Vector2(476, -56), Vector2(464, -56), Vector2(452, -48), Vector2(440, -44),
	Vector2(428, -40), Vector2(416, -40), Vector2(404, -36), Vector2(392, -28), Vector2(380, -20), Vector2(368, -12),
	Vector2(356, 0), Vector2(344, 12), Vector2(332, 24), Vector2(328, 36), Vector2(324, 48), Vector2(324, 60),
	Vector2(324, 72), Vector2(324, 84), Vector2(324, 96), Vector2(324, 108), Vector2(316, 120), Vector2(312, 132),
	Vector2(308, 144), Vector2(300, 156), Vector2(300, 168), Vector2(300, 180), Vector2(300, 192), Vector2(300, 204),
	Vector2(300, 216), Vector2(300, 228), Vector2(300, 240), Vector2(300, 252), Vector2(300, 264), Vector2(300, 276),
	Vector2(300, 288), Vector2(300, 300), Vector2(304, 312), Vector2(312, 324), Vector2(324, 336), Vector2(336, 348),
	Vector2(348, 356), Vector2(360, 356), Vector2(372, 356), Vector2(384, 356), Vector2(396, 356), Vector2(408, 360),
	Vector2(420, 364), Vector2(432, 364), Vector2(444, 364), Vector2(456, 364), Vector2(468, 372), Vector2(472, 376)
])
static var CLEAR := PackedInt32Array([20, 8, 4, 4, 4, 4, 8, 8, 8, 16, 16, 16, 16, 20, 20, 20, 24, 28, 28, 28, 24, 32, 36, 44, 40, 36, 32, 24, 16, 12, 12, 16, 16, 16, 16, 12, 12, 12, 12, 12, 12, 8, 8, 12, 16, 8, 8, 8, 12, 12, 16, 16, 16, 12, 12, 12, 12, 16, 20, 24, 24, 28, 32, 28, 28, 28, 24, 24, 16, 16, 12, 16, 16, 16, 12, 12, 16, 20, 20, 28, 32, 32, 32, 40, 32, 28, 24, 24, 24, 20, 24, 24, 24, 32, 32, 32, 24, 24, 24, 16, 12, 12, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 12, 12, 12, 12, 16, 20, 20, 20, 24, 24, 24, 28, 32, 36, 28, 28, 32, 28, 32, 40, 52, 52, 52, 52, 52, 52, 44, 48, 52, 52, 56, 56, 52, 52, 52, 48, 48, 32, 32, 32, 28, 32, 28, 28, 28, 28, 24, 20, 20, 24, 20, 20, 20, 24, 24, 28, 24, 24, 36, 40, 40, 44, 36, 32, 32, 32, 32, 32, 32, 32, 32, 28, 28, 28, 28, 28, 32, 36, 36, 32, 32, 32, 28, 28, 28, 32, 32, 32, 32, 32, 32, 32, 36, 44, 48, 48, 48, 44, 36, 24, 32, 44, 44, 44, 44, 40, 40, 40, 40, 36, 32, 32, 32, 36, 36, 36, 36, 44, 36, 32, 28, 24, 24, 28, 28, 32, 32, 28, 28, 28, 24, 32, 32, 32, 32, 32, 28, 28, 28, 32, 32, 36, 32, 32, 28, 32, 20, 20, 24, 28, 32, 32, 28, 32, 32, 36, 36, 40, 52, 40, 28, 20, 20, 24, 24, 32, 40, 40, 40, 36, 28, 24, 16, 16, 16, 16, 20, 20, 20, 16, 12])
const START_IDX := 1
const SWORD_IDX := 9
const FIRST_SITE := 18
const SPAWN_GAP := 3      # route points kept clear before the final site
const TUNNEL_LEN := 11    # route points covered by the tunnel (between boss 1 and quest 11)

static var _sites: Array = []
static var _tunnel_start := 0


static func start() -> Vector2:
	return ROUTE[START_IDX]


static func sword_spot() -> Vector2:
	return ROUTE[SWORD_IDX] + Vector2(3, 3)


static func _build() -> void:
	_sites.clear()
	var last := ROUTE.size() - 1 - SPAWN_GAP - TUNNEL_LEN
	for i in 40:
		var nominal := FIRST_SITE + int(round(float(i) * float(last - FIRST_SITE) / 39.0))
		if i >= 10:
			nominal += TUNNEL_LEN  # the tunnel takes up route length after quest 10
		var pick := nominal
		if (i + 1) % 10 == 0 and i < 39:
			var best := -1
			var lo := nominal - 7
			var hi := nominal + 8
			if i == 9:
				hi = nominal + 1  # the tunnel starts right after the first boss arena
			for k in range(lo, hi):
				if k > 0 and k < ROUTE.size() and CLEAR[k] > best:
					best = CLEAR[k]
					pick = k
		_sites.append(pick)
	_tunnel_start = int(_sites[9]) + 5


## Route index for quest n (1..40). Boss quests snap to the widest clearing nearby.
static func site_index(n: int) -> int:
	if _sites.is_empty():
		_build()
	return _sites[clampi(n, 1, 40) - 1]


static func site(n: int) -> Vector2:
	return ROUTE[site_index(n)]


## First/last route index of the tunnel.
static func tunnel_range() -> Vector2i:
	if _sites.is_empty():
		_build()
	return Vector2i(_tunnel_start, _tunnel_start + TUNNEL_LEN)


## Unit direction of travel along the road at route index i.
static func dir_at(i: int) -> Vector2:
	var a := ROUTE[clampi(i - 2, 0, ROUTE.size() - 1)]
	var b := ROUTE[clampi(i + 2, 0, ROUTE.size() - 1)]
	return (b - a).normalized()


## Where the player stands when (re)starting quest n: the previous quest's site (or the start).
static func checkpoint(n: int) -> Vector2:
	if n <= 1:
		return start()
	return ROUTE[site_index(n - 1)] + Vector2(3, 4)


## Route points between two route indices (for wayside encounters).
static func between(i0: int, i1: int, count: int) -> Array:
	var out: Array = []
	for k in count:
		var f := float(k + 1) / float(count + 1)
		out.append(ROUTE[int(lerpf(i0, i1, f))])
	return out
