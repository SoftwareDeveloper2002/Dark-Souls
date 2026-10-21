extends RefCounted
## The 40-quest campaign: rescue Princess Elara from the Dark Lord Malakar.
## Quests 10 / 20 / 30 / 40 are boss fights. Bosses 10-30 each hold a key to the Dark Citadel.

const MAX_QUEST := 40

const CHAPTERS := [
	{"name": "THE ASHEN GATE", "sub": "CHAPTER I", "boss": "demon", "fog": Color(0.03, 0.04, 0.09), "ambient": Color(0.28, 0.32, 0.5),
		"moon": Color(0.6, 0.7, 1.0), "moon_e": 0.9, "thunder": [9.0, 18.0], "rain": 220},
	{"name": "THE SUNKEN CRYPT", "sub": "CHAPTER II", "boss": "serpent", "fog": Color(0.02, 0.07, 0.06), "ambient": Color(0.22, 0.42, 0.36),
		"moon": Color(0.5, 0.95, 0.8), "moon_e": 0.8, "thunder": [8.0, 15.0], "rain": 300},
	{"name": "THE WAILING KEEP", "sub": "CHAPTER III", "boss": "cyborg", "fog": Color(0.06, 0.07, 0.12), "ambient": Color(0.4, 0.46, 0.62),
		"moon": Color(0.8, 0.88, 1.0), "moon_e": 1.0, "thunder": [6.0, 12.0], "rain": 420},
	{"name": "THE DARK CITADEL", "sub": "CHAPTER IV", "boss": "malakar", "fog": Color(0.1, 0.02, 0.03), "ambient": Color(0.4, 0.2, 0.24),
		"moon": Color(0.95, 0.5, 0.45), "moon_e": 0.85, "thunder": [4.0, 9.0], "rain": 520},
]

const TITLES := [
	"The Ashen Road", "Broken Banners", "Wolves of the Wall", "Hold the Gate", "Captain Varek",
	"Archers in the Mist", "The Long Watch", "Pillars of Ash", "Captain Rhogar", "The Asylum Demon",
	"Beyond the Tunnel", "Bones Underfoot", "The Whispering Hall", "Hold the Stair", "Captain Morrow",
	"Arrows in the Dark", "Vigil of the Dead", "The Tomb Road", "Captain Sable", "The Serpent Queen",
	"Winter's Edge", "Cultists of the Veil", "The Frozen Bridge", "Hold the Rampart", "Captain Isolde",
	"Storm Callers", "The Labyrinth of Echoes", "Gargoyle Row", "Captain Draven", "The Cyborg Titan",
	"The Black Gate", "Blood Courtyard", "Hall of Knights", "Hold the Bridge", "Captain Vael",
	"Crimson Casters", "The Last Stand", "The Throne Road", "Captain Kroth", "Lord Malakar",
]

# [enemy kind, weight, min quest-in-chapter]
const POOLS := [
	[["hollow", 5, 1], ["zombie", 4, 1], ["imp", 2, 3], ["archer", 2, 4], ["hound", 1, 6]],
	[["skeleton", 5, 1], ["zombie", 3, 1], ["ghoul", 3, 2], ["hound", 3, 3], ["archer", 2, 1], ["knight", 1, 6]],
	[["mage", 3, 1], ["stonesoldier", 3, 1], ["fiend", 2, 2], ["imp", 3, 1], ["knight", 2, 3], ["hound", 2, 2], ["ghoul", 2, 4]],
	[["knight", 3, 1], ["fiend", 3, 1], ["brute", 2, 2], ["mage", 3, 1], ["skeleton", 2, 1], ["ghoul", 2, 1], ["hound", 2, 2], ["imp", 2, 1]],
]

const BOSS_REWARDS := {
	10: {"souls": 1500, "key": "BRONZE KEY", "weapon": "cleaver", "armor": "demon"},
	20: {"souls": 3000, "key": "SILVER KEY", "weapon": "spear", "armor": "serpent"},
	30: {"souls": 5200, "key": "GOLD KEY", "weapon": "", "armor": "cyborg"},
	40: {"souls": 8000, "key": "", "weapon": "", "armor": ""},
}

const INTRO := [
	["", "Night falls over the kingdom of Eldoria. The Dark Lord Malakar has broken the royal gates and stolen away Princess Elara, the last light of the Ashen Throne."],
	["", "He has carried her to the Dark Citadel, sealed behind three keys. Each key is held by one of his lieutenants. The kingdom has fallen. Only one knight remains."],
	["", "You are the last of the Ashen Order. Arm yourself... and bring her home."],
]

const CHAPTER_START := [
	[["ELARA", "(a faint voice on the wind) Knight... if you can hear me... follow the ash road. I will hold on."]],
	[["", "Beyond the gate lies the Sunken Crypt. The dead do not rest here. Malakar's curse has woken them all."]],
	[["", "Snow and storm swallow the Wailing Keep. Somewhere in the howling dark, the Dread Queen calls the lightning."]],
	[["ELARA", "(a whisper through the stone) You are close... I can feel your light. Do not stop now."], ["", "The Dark Citadel looms ahead. Beyond it waits Malakar... and the princess."]],
]

const BOSS_INTRO := {
	10: [["ASYLUM DEMON", "The princess? She is far beyond you, little knight. My shield cannot be broken. Turn back, or be crushed!"]],
	20: [["SERPENT QUEEN", "Sssss... look into my eyes, Ashen knight, and join my garden of stone. My children will tear what remains."]],
	30: [["CYBORG TITAN", "TARGET ACQUIRED. THE BRIDGE IS THE ONLY WAY ACROSS. YOU WILL NOT SURVIVE IT."]],
	40: [["MALAKAR", "You came all this way for a girl? I have devoured the power of every guardian you killed. Kneel, Ashen knight."]],
}

const BOSS_DEFEAT := {
	10: [["", "The Asylum Demon falls, its shield shattered. From its hoard you take the BRONZE KEY, the DEMON CLEAVER and the crimson DEMON PLATE."]],
	20: [["", "The Serpent Queen coils and goes still. Among her gold lies the SILVER KEY, the SERPENT FANG spear and a coat of SERPENT SCALE."]],
	30: [["", "The Cyborg Titan sparks, shudders, and collapses into the chasm. You pull the GOLD KEY and TITAN PLATING from its wreckage. The Dark Citadel's gate will open."]],
	40: [["MALAKAR", "Impossible... I took their power... the dawn... I cannot..."],
		["", "The Dark Lord crumbles to ash. The cage opens, and Princess Elara steps into the light."],
		["ELARA", "I knew you would come. Thank you, brave knight. The long night is over."],
		["", "Dawn breaks over Eldoria. You have saved the princess."]],
}

const MAZE_TEXT := [["", "The road vanishes into a labyrinth of towering old stone, black as a grave. Villagers fled in here when the monsters came, and now they cower in its dead ends. Find them all and lead them across the labyrinth to the far gate - and keep every one of them alive. If a single civilian dies, the labyrinth resets."], ["", "It is pitch dark. Your torch is your only light - and while you carry it you cannot raise a weapon. Drop it on the ground to fight, then pick it up again. Tap COMMAND to tell the rescued to follow you or stay put. Somewhere inside, the Ashen Order hid a gun, forged for the last war."]]

const TUNNEL_TEXT := [["", "A great tunnel yawns ahead, the only way down into the Sunken Crypt. Torches gutter in the dark. Something shuffles inside."]]


static func chapter_of(n: int) -> int:
	return clampi((n - 1) / 10, 0, 3)


static func is_boss(n: int) -> bool:
	return n % 10 == 0


static func quest(n: int) -> Dictionary:
	var ch := chapter_of(n)
	var idx := (n - 1) % 10 + 1
	var q := {"n": n, "ch": ch, "idx": idx, "title": TITLES[n - 1], "boss": ""}
	var pool: Array = []
	for e in POOLS[ch]:
		if idx >= int(e[2]):
			pool.append([e[0], int(e[1])])
	q.table = pool
	q.max_alive = mini(3 + n / 9, 7)
	q.interval = maxf(1.6, 3.2 - n * 0.03)
	if idx == 10:
		q.kind = "boss"
		q.boss = CHAPTERS[ch].boss
		q.text = "Defeat %s" % str(q.title).to_upper()
		q.target = 1
	elif n == 27:
		q.kind = "maze"
		q.text = "Find the treasure in the labyrinth"
		q.target = 1
	elif idx == 5 or idx == 9:
		q.kind = "elite"
		q.text = "Defeat the Captain"
		q.target = 1
	elif idx == 4 or idx == 7:
		q.kind = "survive"
		q.target = 28 + n
		q.text = "Survive the onslaught"
	else:
		q.kind = "kill"
		q.target = 6 + int((n - 1) * 0.3) + idx / 2
		q.text = "Slay the enemy"
	q.scale = 1.0 + 0.055 * (n - 1)  # enemy health scaling
	q.dmg_scale = 1.0 + 0.035 * (n - 1)
	return q
