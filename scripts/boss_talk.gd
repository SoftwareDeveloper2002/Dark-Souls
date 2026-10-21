extends RefCounted
## Boss trash-talk: bosses jeer at the hero mid-fight through speech bubbles (game.speak) with voiced syllables.
## Triggers: first blood, hero low on health, hero drinking, hero rolling / blocking, boss wounded, phase changes,
## idle taunts, killing the hero and a last gasp on defeat.

var g  # the game node

const VOICE := {
	"demon": {"snd": "v", "pitch": 0.55, "col": Color("ff9a5a")},
	"serpent": {"snd": "h", "pitch": 0.95, "col": Color("7aff9a")},
	"cyborg": {"snd": "m", "pitch": 0.5, "col": Color("5ae8ff")},
	"malakar": {"snd": "v", "pitch": 0.42, "col": Color("ff4a5a")},
}

const LINES := {
	"demon": {
		"engage": ["Come, little knight. Let me hear your bones crack!", "My shield has broken better men than you."],
		"hit": ["HAH! Did that hurt?", "Weak. So weak.", "Crawl back to your fire!"],
		"low": ["You are nearly dead. Beg!", "I can smell your fear, knight."],
		"heal": ["Drink, drink! It will not save you!", "Stalling? Pathetic!"],
		"hurt": ["A scratch! You call that a blow?", "You only make me angrier!", "Hmph... lucky strike."],
		"dodge": ["Run, little rat!", "Dancing will not save you!"],
		"block": ["Hide behind your tin plate!", "Your shield will shatter, like the rest."],
		"phase": ["ENOUGH! FEEL MY WRATH!", "NOW I AM SERIOUS!"],
		"idle": ["Is that all the Ashen Order sent?", "Come closer. I will not bite. Much.", "Where is your courage?"],
		"kill": ["Another fool for the asylum floor.", "Told you. Turn back."],
		"death": ["No... the princess... is beyond... you...", "Impossible... a mere knight..."],
	},
	"serpent": {
		"engage": ["Sssss... such a pretty statue you will make.", "Welcome to my garden, little knight."],
		"hit": ["Sss... sweet, sweet pain.", "Bleed for me, Ashen one.", "My venom runs in you now!"],
		"low": ["You are fading... how delicious.", "Ssslow now... sssleep."],
		"heal": ["Sssip your potion... it only prolongs the fun.", "Sssuch desperation!"],
		"hurt": ["You dare cut the Queen?!", "Sss... a bite for a bite!", "My children will feast on you!"],
		"dodge": ["You cannot sssslither away!", "Run, run, sssmall thing."],
		"block": ["Hiding? How very reptilian.", "Sssscared of my gaze?"],
		"phase": ["SSSSEE MY TRUE FORM!", "THE GARDEN AWAKENS!"],
		"idle": ["Look into my eyes... look...", "Sssso much stone to add to my garden.", "Do not struggle..."],
		"kill": ["Sssss... another one for the garden.", "Sleep, little knight."],
		"death": ["Sss... my garden... withers...", "The... stone... cracks..."],
	},
	"cyborg": {
		"engage": ["TARGET LOCKED. PROBABILITY OF SURVIVAL: 0.3 PERCENT.", "INTRUDER DETECTED. INITIATING PURGE."],
		"hit": ["DAMAGE CONFIRMED. CONTINUING.", "HOSTILE WEAKENING.", "IMPACT SUCCESSFUL."],
		"low": ["HOSTILE VITALS CRITICAL. TERMINATION IMMINENT.", "YOUR HEARTBEAT IS FAILING."],
		"heal": ["HEALING DETECTED. FUTILE.", "CONSUMABLE USE DOES NOT ALTER OUTCOME."],
		"hurt": ["ARMOUR INTEGRITY DECLINING. RECALCULATING.", "MINOR DAMAGE. IGNORED.", "SYSTEMS NOMINAL. MOSTLY."],
		"dodge": ["EVASION PATTERN LOGGED.", "RUNNING ONLY DELAYS DELETION."],
		"block": ["SHIELD ANALYSIS: INSUFFICIENT.", "DEFENCE WILL BE BREACHED."],
		"phase": ["WARNING. WEAPONS SYSTEMS UNLEASHED.", "OVERRIDE ENGAGED. NO MERCY PROTOCOL."],
		"idle": ["SCANNING... SCANNING... YOU ARE STILL HERE.", "THE BRIDGE IS MY DOMAIN.", "SURRENDER IS NOT IN YOUR PROGRAMMING."],
		"kill": ["TARGET ELIMINATED. MISSION COMPLETE.", "HOSTILE TERMINATED."],
		"death": ["CRITICAL... FAILURE... SHUTTING... DOWN...", "ERR... OR... THE... GATE... OPENS..."],
	},
	"malakar": {
		"engage": ["So the little knight finally crawls to my throne.", "Dawn will never come, Ashen one."],
		"hit": ["Feel the dark, knight!", "Did you think you could win?", "Your light is so dim."],
		"low": ["Look at you. Barely standing. Kneel!", "Your princess will watch you die."],
		"heal": ["Heal all you like. I devoured the guardians!", "A flask? How quaint."],
		"hurt": ["Hah! You scratch a god!", "Enough games!", "You only delay the inevitable."],
		"dodge": ["Fleeing? Just like the others.", "There is nowhere to hide from me!"],
		"block": ["Your shield is nothing before the abyss!", "Break, little wall, break!"],
		"phase": ["YOU WILL WITNESS TRUE DARKNESS!", "BEHOLD THE POWER OF EVERY GUARDIAN!", "KNEEL!"],
		"idle": ["Elara screams your name. Can you hear her?", "Come, take my head. If you can.", "I have waited a thousand nights for you."],
		"kill": ["Darkness wins. As it always does.", "Elara is mine. Forever."],
		"death": ["I took their power... the dawn... I cannot...", "Impossible... the light... fades me..."],
	},
}


func setup(game) -> void:
	g = game


func voice_of(type: String) -> Dictionary:
	return VOICE.get(type, VOICE.demon)


func _state(e: Dictionary) -> Dictionary:
	if not e.has("tk"):
		e["tk"] = {"cd": 2.5, "idle": randf_range(10.0, 16.0), "last_hp": g.p_hp, "low": false, "flasks": g.flasks,
			"marks": {0.75: false, 0.5: false, 0.25: false}, "dodge_cd": 0.0, "block_cd": 0.0, "engaged": false, "last": {}}
	return e["tk"]


## Say a line of the given kind; `force` ignores the cool-down between remarks.
func say(e: Dictionary, kind: String, force: bool = false) -> void:
	var table: Dictionary = LINES.get(e.type, {})
	if not table.has(kind):
		return
	var tk := _state(e)
	if not force and float(tk.cd) > 0.0:
		return
	var pool: Array = table[kind]
	var pick: String = pool[randi() % pool.size()]
	if pool.size() > 1 and tk.last.get(kind, "") == pick:
		pick = pool[(pool.find(pick) + 1) % pool.size()]
	tk.last[kind] = pick
	tk.cd = 5.0 if kind != "death" else 99.0
	g.speak(e, pick, kind == "death")


## Called every frame for each living boss that is in the fight.
func update(e: Dictionary, dt: float) -> void:
	if e.dead or g.state != "play":
		return
	var tk := _state(e)
	tk.cd = maxf(0.0, float(tk.cd) - dt)
	tk.dodge_cd = maxf(0.0, float(tk.dodge_cd) - dt)
	tk.block_cd = maxf(0.0, float(tk.block_cd) - dt)
	tk.idle = float(tk.idle) - dt
	if not tk.engaged:
		tk.engaged = true
		say(e, "engage", true)
		return
	if g.p_hp < float(tk.last_hp) - 0.5:
		if randf() < 0.5:
			say(e, "hit")
	tk.last_hp = g.p_hp
	if not tk.low and g.p_hp < g.p_max_hp * 0.3 and g.p_hp > 0.0:
		tk.low = true
		say(e, "low", true)
	elif tk.low and g.p_hp > g.p_max_hp * 0.55:
		tk.low = false
	if g.flasks < int(tk.flasks):
		say(e, "heal")
	tk.flasks = g.flasks
	var frac: float = e.hp / maxf(e.max_hp, 1.0)
	for m in tk.marks.keys():
		if not tk.marks[m] and frac < float(m):
			tk.marks[m] = true
			say(e, "hurt", true)
	if g.p_act == "roll" and float(tk.dodge_cd) <= 0.0:
		tk.dodge_cd = 9.0
		if randf() < 0.35:
			say(e, "dodge")
	if g.p_shield_hit > 0.25 and float(tk.block_cd) <= 0.0:
		tk.block_cd = 10.0
		if randf() < 0.5:
			say(e, "block")
	if float(tk.idle) <= 0.0:
		tk.idle = randf_range(13.0, 21.0)
		say(e, "idle")
