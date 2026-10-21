extends RefCounted
## Bonfire shop: weapon forging, stats, skills, supplies (potions + ammo) and equipment.

const UI := preload("res://scripts/ui.gd")
const Weapons := preload("res://scripts/weapons.gd")

# key, label, effect, max level, base cost
const STATS := [
	["attack", "ATTACK", "+3 damage", 15, 90],
	["vigor", "HEALTH", "+12 max health", 15, 80],
	["endurance", "STAMINA", "+8 max stamina", 15, 70],
	["defense", "DEFENSE", "-4% damage taken", 10, 110],
	["mobility", "MOBILITY", "+3% speed, longer roll", 10, 100],
	["regen", "REGENERATION", "+0.5 health per second", 10, 120],
	["potency", "POTION POWER", "+6 healing per potion", 10, 90],
]
const POTION_COST := 60
const MAX_POTIONS := 9
const AMMO_PACK := 10
const AMMO_COST := 60
const MAX_AMMO := 99
const MAX_SKILL_LV := 5

var g
var root: Control
var on_continue: Callable
var _head: Label
var _list: VBoxContainer
var _tabs: Array = []
var _tab := 0


static func stat_cost(base: int, lvl: int) -> int:
	return int(base * (1.0 + 0.55 * lvl))


func build(game, layer: CanvasLayer) -> void:
	g = game
	var o := UI.overlay("BONFIRE")
	root = o.root
	var box: VBoxContainer = o.box
	box.custom_minimum_size = Vector2(800, 0)
	_head = UI.label("", 19, Color("f2d27a"), HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_head)

	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 8)
	for i in 4:
		var names := ["UPGRADES", "SKILLS", "SUPPLIES", "GEAR"]
		var idx := i
		var b := UI.button(names[i], func(): _set_tab(idx), 170.0)
		b.custom_minimum_size.y = 42
		tabs.add_child(b)
		_tabs.append(b)
	box.add_child(tabs)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 300)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)

	var cont := UI.button("CONTINUE THE QUEST", func(): if on_continue.is_valid(): on_continue.call(), 340.0)
	cont.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(cont)
	root.visible = false
	layer.add_child(root)


func open() -> void:
	root.visible = true
	_set_tab(_tab)


func close() -> void:
	root.visible = false


func _set_tab(i: int) -> void:
	_tab = i
	for k in _tabs.size():
		_tabs[k].modulate = Color(1, 0.85, 0.5) if k == i else Color(1, 1, 1, 0.75)
	refresh()


func _row(title: String, level: String, effect: String, btn: String, enabled: bool, cb: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var nm := UI.label(title, 18)
	nm.custom_minimum_size = Vector2(190, 0)
	var lv := UI.label(level, 16, Color("f2d27a"))
	lv.custom_minimum_size = Vector2(90, 0)
	var fx := UI.label(effect, 14, Color(UI.BONE, 0.65))
	fx.custom_minimum_size = Vector2(250, 0)
	fx.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var b := UI.button(btn, cb, 160.0)
	b.custom_minimum_size.y = 44
	b.add_theme_font_size_override("font_size", 17)
	b.disabled = not enabled
	row.add_child(nm)
	row.add_child(lv)
	row.add_child(fx)
	row.add_child(b)
	_list.add_child(row)


func refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	_head.text = "SOULS  %d     POTIONS  %d/%d     KEYS  %d/3%s" % [g.souls, g.flasks, MAX_POTIONS, g.keys,
		("     AMMO  %d" % g.ammo) if g.weapons_owned.gun else ""]
	match _tab:
		0:
			var id: String = g.equipped
			var t: int = g.wtier[id]
			var w: Dictionary = Weapons.W[id]
			if t < 4:
				var cost := int(w.cost[t + 1])
				_row("FORGE: " + str(w.name).to_upper(), "Tier %d" % (t + 1), "%s  ->  %s  (%d dmg)" % [w.names[t], w.names[t + 1], int(w.dmg[t + 1])],
					"FORGE  %d" % cost, g.souls >= cost, func(): _buy_tier())
			else:
				_row("FORGE: " + str(w.name).to_upper(), "MAX", "%s  (%d dmg)" % [w.names[t], int(w.dmg[t])], "MAXED", false, func(): pass)
			for s in STATS:
				if s[0] == "potency":
					continue
				_stat_row(s)
		1:
			# every weapon has its own two skills: the ones shown are for the weapon in hand
			var wn := str(Weapons.W[g.equipped].name)
			for slot in 2:
				var sk: Dictionary = Weapons.SKILLS[g.equipped][slot]
				var st: Dictionary = g.skills[g.equipped][slot]
				var title := "%s   (%s)" % [sk.name, wn]
				if not st.u:
					_row(title, "LOCKED", sk.desc, "UNLOCK  %d" % int(sk.unlock), g.souls >= int(sk.unlock), func(): _buy_skill(slot, true))
				elif st.l < MAX_SKILL_LV:
					var cost := int(sk.lvl_cost * (1.0 + 0.6 * st.l))
					_row(title, "Lv %d/%d" % [st.l + 1, MAX_SKILL_LV + 1], sk.desc, "UPGRADE  %d" % cost, g.souls >= cost, func(): _buy_skill(slot, false))
				else:
					_row(title, "MAX", sk.desc, "MAXED", false, func(): pass)
		2:
			_row("HEALING POTION", "x%d" % g.flasks, "Restores health. Carry up to %d" % MAX_POTIONS, "BUY  %d" % POTION_COST,
				g.souls >= POTION_COST and g.flasks < MAX_POTIONS, func(): _buy_potion())
			if g.weapons_owned.gun:
				_row("REVOLVER AMMO", "x%d" % g.ammo, "A pack of %d bullets. Enemies also drop ammo." % AMMO_PACK, "BUY  %d" % AMMO_COST,
					g.souls >= AMMO_COST and g.ammo < MAX_AMMO, func(): _buy_ammo())
			else:
				_row("REVOLVER AMMO", "LOCKED", "Find the revolver in the labyrinth (quest 27).", "???", false, func(): pass)
			for s in STATS:
				if s[0] == "potency":
					_stat_row(s)
		3:
			for id in Weapons.ORDER:
				var w2: Dictionary = Weapons.W[id]
				if g.weapons_owned[id]:
					var eq: bool = g.equipped == id
					_row(Weapons.weapon_name(id, g.wtier[id]).to_upper(), "Tier %d" % (g.wtier[id] + 1),
						"%d damage  -  %s" % [int(w2.dmg[g.wtier[id]]), str(w2.style).capitalize()], "EQUIPPED" if eq else "EQUIP", not eq, func(): _equip_w(id))
				else:
					_row(str(w2.name).to_upper(), "LOCKED", "Found or won in the world.", "???", false, func(): pass)
			for aid in Weapons.ARMOR_ORDER:
				var a: Dictionary = Weapons.ARMOR[aid]
				if g.armors_owned[aid]:
					var eqa: bool = g.armor == aid
					_row(str(a.name).to_upper(), "ARMOR", str(a.desc), "WORN" if eqa else "WEAR", not eqa, func(): _equip_a(aid))
				else:
					_row(str(a.name).to_upper(), "LOCKED", "Dropped by a boss.", "???", false, func(): pass)


func _stat_row(s: Array) -> void:
	var key: String = s[0]
	var lvl: int = g.lv[key]
	var mx: int = s[3]
	if lvl >= mx:
		_row(s[1], "MAX", s[2], "MAXED", false, func(): pass)
	else:
		var cost := stat_cost(int(s[4]), lvl)
		_row(s[1], "Lv %d/%d" % [lvl, mx], s[2], "BUY  %d" % cost, g.souls >= cost, func(): _buy_stat(key, int(s[4])))


func _buy_stat(key: String, base: int) -> void:
	var cost := stat_cost(base, g.lv[key])
	if g.souls < cost:
		return
	g.souls -= cost
	g.lv[key] += 1
	g.recalc()
	g.sfx("chime", -10.0, 1.4)
	refresh()


func _buy_tier() -> void:
	var id: String = g.equipped
	var t: int = g.wtier[id]
	if t >= 4:
		return
	var cost := int(Weapons.W[id].cost[t + 1])
	if g.souls < cost:
		return
	g.souls -= cost
	g.wtier[id] = t + 1
	g.style_weapon()
	g.sfx("chime", -6.0, 1.0)
	refresh()


func _buy_skill(slot: int, unlock: bool) -> void:
	var sk: Dictionary = Weapons.SKILLS[g.equipped][slot]
	var st: Dictionary = g.skills[g.equipped][slot]
	var cost := int(sk.unlock) if unlock else int(sk.lvl_cost * (1.0 + 0.6 * st.l))
	if g.souls < cost:
		return
	g.souls -= cost
	if unlock:
		st.u = true
	else:
		st.l += 1
	g.sfx("chime", -6.0, 1.2)
	g.refresh_skill_buttons()
	refresh()


func _buy_potion() -> void:
	if g.souls < POTION_COST or g.flasks >= MAX_POTIONS:
		return
	g.souls -= POTION_COST
	g.flasks += 1
	g.controls.flasks = g.flasks
	g.sfx("potion", -8.0, 1.0)
	refresh()


func _buy_ammo() -> void:
	if g.souls < AMMO_COST or g.ammo >= MAX_AMMO:
		return
	g.souls -= AMMO_COST
	g.ammo = mini(MAX_AMMO, g.ammo + AMMO_PACK)
	g.sfx("hit", -4.0, 1.6)
	g.refresh_weapon_ui()
	refresh()


func _equip_w(id: String) -> void:
	g.equip_weapon(id)
	g.sfx("chime", -8.0, 1.5)
	refresh()


func _equip_a(id: String) -> void:
	g.equip_armor(id)
	g.sfx("chime", -8.0, 1.2)
	refresh()
