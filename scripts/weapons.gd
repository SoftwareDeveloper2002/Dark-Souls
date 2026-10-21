extends RefCounted
## Weapon and armour data. Weapons upgrade through 5 tiers; armour sets are boss rewards.

const W := {
	"sword": {"name": "Ashen Longsword", "icon": "sword", "style": "slash",
		"names": ["Blade of the Fallen", "Knight's Longsword", "Moonlight Greatblade", "Dragonbane", "Aegis of Dawn"],
		"dmg": [24.0, 38.0, 56.0, 80.0, 112.0], "cost": [0, 700, 2200, 5200, 10000],
		"range": 3.8, "arc": 1.1, "stam": 18.0, "time": 0.42, "hit_t": 0.14, "lunge": 6.0},
	"cleaver": {"name": "Demon Cleaver", "icon": "axe", "style": "overhead",
		"names": ["Demon Cleaver", "Infernal Cleaver", "Hellforged Cleaver", "Archdemon Cleaver", "Cleaver of the Abyss"],
		"dmg": [72.0, 102.0, 142.0, 192.0, 262.0], "cost": [0, 1200, 3200, 7000, 14000],
		"range": 4.6, "arc": 1.7, "stam": 30.0, "time": 0.78, "hit_t": 0.4, "lunge": 2.0},
	"spear": {"name": "Serpent Fang", "icon": "spear", "style": "thrust",
		"names": ["Serpent Fang", "Basilisk Fang", "Gorgon Lance", "Viper King's Lance", "Fang of the Eternal Serpent"],
		"dmg": [44.0, 62.0, 86.0, 118.0, 158.0], "cost": [0, 900, 2600, 6000, 12000],
		"range": 6.2, "arc": 0.5, "stam": 14.0, "time": 0.46, "hit_t": 0.2, "lunge": 9.0},
	"gun": {"name": "Ashen Revolver", "icon": "gun", "style": "shoot",
		"names": ["Ashen Revolver", "Hunter's Revolver", "Silver Revolver", "Stormcaller Revolver", "Dawnbreaker"],
		"dmg": [22.0, 32.0, 46.0, 64.0, 88.0], "cost": [0, 800, 2400, 5600, 11000],
		"range": 26.0, "arc": 0.0, "stam": 3.0, "time": 0.3, "hit_t": 0.0, "lunge": 0.0},
}
const ORDER := ["sword", "cleaver", "spear", "gun"]

## Four-strike chains per weapon. Every field multiplies / overrides the base weapon stats:
## anim = pose played, dmg/range/arc/stam/lunge = multipliers, time/hit_t = seconds, hits = hit moments (s),
## kb = knockback multiplier, slam = cracks the ground in front of the hero.
const COMBO := {
	"sword": [
		{"anim": "slash_r", "dmg": 1.0, "range": 1.0, "arc": 1.0, "stam": 1.0, "lunge": 1.0, "time": 0.42, "hit_t": 0.14, "kb": 1.0},
		{"anim": "slash_l", "dmg": 1.05, "range": 1.0, "arc": 1.0, "stam": 1.0, "lunge": 1.0, "time": 0.40, "hit_t": 0.13, "kb": 1.0},
		{"anim": "diag", "dmg": 1.3, "range": 1.05, "arc": 0.85, "stam": 1.2, "lunge": 1.1, "time": 0.52, "hit_t": 0.22, "kb": 1.4},
		{"anim": "lunge", "dmg": 1.8, "range": 1.3, "arc": 0.5, "stam": 1.6, "lunge": 1.7, "time": 0.66, "hit_t": 0.3, "kb": 2.4},
	],
	"cleaver": [
		{"anim": "overhead", "dmg": 1.0, "range": 1.0, "arc": 1.0, "stam": 1.0, "lunge": 1.0, "time": 0.78, "hit_t": 0.4, "kb": 1.0, "slam": true},
		{"anim": "sweep", "dmg": 0.85, "range": 1.05, "arc": 1.3, "stam": 0.85, "lunge": 1.2, "time": 0.62, "hit_t": 0.28, "kb": 1.5},
		{"anim": "upper", "dmg": 1.1, "range": 0.95, "arc": 0.9, "stam": 1.0, "lunge": 1.0, "time": 0.7, "hit_t": 0.3, "kb": 2.0},
		{"anim": "overhead", "dmg": 1.7, "range": 1.15, "arc": 1.2, "stam": 1.5, "lunge": 0.6, "time": 1.0, "hit_t": 0.56, "kb": 3.0, "slam": true},
	],
	"spear": [
		{"anim": "thrust", "dmg": 1.0, "range": 1.0, "arc": 1.0, "stam": 1.0, "lunge": 1.0, "time": 0.46, "hit_t": 0.2, "kb": 1.0},
		{"anim": "sweep", "dmg": 0.8, "range": 0.85, "arc": 2.2, "stam": 0.9, "lunge": 0.4, "time": 0.5, "hit_t": 0.22, "kb": 1.6},
		{"anim": "double", "dmg": 0.75, "range": 1.0, "arc": 1.0, "stam": 1.1, "lunge": 0.9, "time": 0.7, "hit_t": 0.18, "kb": 0.8, "hits": [0.18, 0.4]},
		{"anim": "vault", "dmg": 1.7, "range": 1.1, "arc": 0.8, "stam": 1.5, "lunge": 1.5, "time": 0.7, "hit_t": 0.34, "kb": 2.5},
	],
}

const ARMOR := {
	"ashen": {"name": "Ashen Plate", "def": 0.0, "hp": 0, "st": 0, "mob": 0.0, "desc": "The old order's armour."},
	"demon": {"name": "Demon Plate", "def": 0.12, "hp": 30, "st": 0, "mob": 0.0, "desc": "+12% defense, +30 health"},
	"serpent": {"name": "Serpent Scale", "def": 0.10, "hp": 0, "st": 20, "mob": 0.08, "desc": "+10% defense, +20 stamina, +8% speed"},
	"cyborg": {"name": "Titan Plating", "def": 0.20, "hp": 50, "st": 10, "mob": 0.0, "desc": "+20% defense, +50 health"},
}
const ARMOR_ORDER := ["ashen", "demon", "serpent", "cyborg"]


## Two skills per weapon (slot a = first button, slot b = second). act = the player action that plays, st = stamina, cd = base cooldown, ammo = bullets used.
const SKILLS := {
	"sword": [
		{"id": "whirl", "name": "WHIRLWIND", "label": "WHIRL", "desc": "Spin and strike every foe around you", "unlock": 600, "lvl_cost": 400, "st": 20.0, "cd": 7.0, "act": "spin"},
		{"id": "thunder", "name": "THUNDER SMITE", "label": "THUNDER", "desc": "Call down lightning on your enemies", "unlock": 1500, "lvl_cost": 700, "st": 25.0, "cd": 11.0, "act": "cast"},
	],
	"cleaver": [
		{"id": "quake", "name": "EARTHQUAKE", "label": "QUAKE", "desc": "Leap and smash the ground, flattening everything near", "unlock": 800, "lvl_cost": 500, "st": 30.0, "cd": 9.0, "act": "quake"},
		{"id": "rage", "name": "BLOOD RAGE", "label": "RAGE", "desc": "Roar: +50% damage and faster for a few seconds", "unlock": 1800, "lvl_cost": 800, "st": 25.0, "cd": 16.0, "act": "rage"},
	],
	"spear": [
		{"id": "dash", "name": "SKEWER DASH", "label": "DASH", "desc": "Charge forward, impaling everything in your path", "unlock": 700, "lvl_cost": 450, "st": 25.0, "cd": 7.0, "act": "dash"},
		{"id": "flurry", "name": "VIPER FLURRY", "label": "FLURRY", "desc": "A blinding storm of thrusts", "unlock": 1600, "lvl_cost": 750, "st": 30.0, "cd": 10.0, "act": "flurry"},
	],
	"gun": [
		{"id": "fan", "name": "FAN THE HAMMER", "label": "FAN", "desc": "Empty six shots in a spread (uses 3 ammo)", "unlock": 700, "lvl_cost": 450, "st": 15.0, "cd": 6.0, "act": "fan", "ammo": 3},
		{"id": "blast", "name": "EXPLOSIVE ROUND", "label": "BLAST", "desc": "A shell that explodes on impact (uses 2 ammo)", "unlock": 1600, "lvl_cost": 750, "st": 20.0, "cd": 9.0, "act": "blast", "ammo": 2},
	],
}


static func fresh_skills() -> Dictionary:
	var d := {}
	for id in SKILLS:
		d[id] = [{"u": false, "l": 0}, {"u": false, "l": 0}]
	return d


static func fresh_cds() -> Dictionary:
	var d := {}
	for id in SKILLS:
		d[id] = [0.0, 0.0]
	return d


static func dmg(id: String, tier: int) -> float:
	return float(W[id].dmg[clampi(tier, 0, 4)])


static func weapon_name(id: String, tier: int) -> String:
	return str(W[id].names[clampi(tier, 0, 4)])
