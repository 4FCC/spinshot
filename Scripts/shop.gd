extends Panel

# =============================================================================
# SHOP — Tienda entre oleadas (con sprites de UI)
# =============================================================================
# Muestra 4 tarjetas (Card_UI_Items) con la info de cada ítem. Los textos
# importantes (TIENDA, ROLL, CONTINUAR, monedas) van sobre el sprite
# Rectangulo_UI_Para_texto. Respeta los límites de compra de cada ítem.

signal continue_pressed

@export var icon_health: Texture2D
@export var icon_damage: Texture2D
@export var icon_speed: Texture2D
@export var icon_firerate: Texture2D
@export var icon_extra1: Texture2D
@export var icon_extra2: Texture2D
@export var icon_coinheal: Texture2D
@export var icon_bounce: Texture2D
@export var icon_split: Texture2D
@export var icon_lethal: Texture2D
@export var icon_autododge: Texture2D

@export_group("Cascos")
@export var icon_basic_helmet: Texture2D
@export var icon_soldier_helmet: Texture2D
@export var icon_viking_helmet: Texture2D
@export var icon_capitan_helmet: Texture2D
@export var icon_grancapitan_helmet: Texture2D

@export var slots: int = 4          # Cuántas tarjetas se muestran a la vez
@export var reroll_cost: int = 3    # Coste de la tirada (ROLL)

const ITEM_CARD := preload("res://Scenes/ItemCard.tscn")
const RECT_TEX := preload("res://UI assets/Rectangulo_UI_Para_texto.png")
const COIN_TEX := preload("res://Items assets/COIN_SPRITE.png")

# Disposición de las 4 tarjetas (espacio base 1280x720).
# CARD_SCALE al máximo que permite encajar 4 tarjetas a lo ancho de 1280.
const CARD_SCALE := 0.78
const CARD_W := 400.0 * CARD_SCALE   # ancho mostrado de cada tarjeta (312)
const CARD_GAP := 6.0
const CARD_X0 := 7.0
const CARD_Y := 165.0

var player: Node2D = null
var _pool: Array = []
var _current: Array = []
var _cards: Array = []
var _coins_label: Label = null
var _reroll_label: Label = null
var _reroll_button: Button = null

func _ready() -> void:
	visible = false
	_build_pool()
	_build_ui()
	Game.coins_changed.connect(func(_t): _refresh())
	# Al cambiar de idioma, refrescar los textos con formato (monedas, ROLL).
	I18n.language_changed.connect(func(_l): _refresh())

func _build_pool() -> void:
	# "max" = compras máximas (0 = ilimitado). "dmg"/"life" = stats que muestra la tarjeta.
	# "name"/"desc" están en inglés (texto fuente) y se auto-traducen en la UI.
	_pool = [
		{"id": "health5", "name": "Minor Health Potion", "cost": 5, "max": 0, "icon": icon_health,
			"desc": "Raises max health by 5 and heals that amount.", "life": 5,
			"apply": func(p): p.upgrade_max_health(5)},
		{"id": "health10", "name": "Greater Health Potion", "cost": 9, "max": 0, "icon": icon_extra1,
			"desc": "Raises max health by 10 and heals that amount.", "life": 10,
			"apply": func(p): p.upgrade_max_health(10)},
		{"id": "dmg1", "name": "Apprentice Wand", "cost": 8, "max": 0, "icon": icon_damage,
			"desc": "+1 damage to each Spin-Bullet.", "dmg": 2,
			"apply": func(p): p.upgrade_bullet_damage(1)},
		{"id": "dmg2", "name": "Arcane Tome", "cost": 14, "max": 0, "icon": icon_extra2,
			"desc": "+2 damage to each Spin-Bullet.", "dmg": 4,
			"apply": func(p): p.upgrade_bullet_damage(2)},
		{"id": "speed", "name": "Beach Sandals", "cost": 6, "max": 0, "icon": icon_speed,
			"desc": "+40 movement speed and reduces dodge cooldown.",
			"apply": func(p):
				p.upgrade_speed(40.0)
				p.reduce_dodge_cooldown(0.1)},
		{"id": "firerate", "name": "Quick Trigger", "cost": 7, "max": 0, "icon": icon_firerate,
			"desc": "Reduces time between shots by 15%; also +move speed and dodge distance.",
			"apply": func(p):
				p.upgrade_fire_rate(0.85)
				p.upgrade_speed(10.0)
				p.increase_dodge_distance(40.0)},
		{"id": "coinheal", "name": "Lifesteal", "cost": 10, "max": 3, "icon": icon_coinheal,
			"desc": "Per level, 25% chance to heal 1-3 when collecting a coin. Max 3.",
			"apply": func(p): p.add_coin_heal()},
		{"id": "bounce", "name": "Offensive bounce", "cost": 15, "max": 3, "icon": icon_bounce,
			"desc": "On hit, releases SpinShots that chain to OTHER enemies. Max 3.",
			"apply": func(p): p.add_bounce()},
		{"id": "split", "name": "Projectile split", "cost": 18, "max": 1, "icon": icon_split,
			"desc": "The SpinShot splits in two mid-path. Unique.",
			"apply": func(p): p.enable_split()},
		{"id": "lethal", "name": "Lethal spin", "cost": 6, "max": 0, "icon": icon_lethal,
			"desc": "+1% per purchase to kill the enemy by spinning. No limit.",
			"apply": func(p): p.add_lethal()},
		{"id": "autododge", "name": "Auto-dodge", "cost": 12, "max": 3, "icon": icon_autododge,
			"desc": "Per level, 25% chance to dodge when hit. Max 3.",
			"apply": func(p): p.add_autododge()},
		# --- Cascos ---
		{"id": "basic_helmet", "name": "Minion Helmet", "cost": 8, "max": 0, "icon": icon_basic_helmet,
			"desc": "-1 max health, +2 damage; longer dodge and shorter dodge cooldown.", "dmg": 2,
			"apply": func(p): p.add_basic_helmet()},
		{"id": "soldier_helmet", "name": "Knight Helmet", "cost": 11, "max": 0, "icon": icon_soldier_helmet,
			"desc": "+5 max health, +3 damage; -20 speed and longer dodge cooldown.", "life": 5, "dmg": 3,
			"apply": func(p): p.add_soldier_helmet()},
		{"id": "viking_helmet", "name": "Viking Helmet", "cost": 13, "max": 0, "icon": icon_viking_helmet,
			"desc": "-3 health, +5 damage; +10% chance to knock back touching enemies (max 50%). Past the cap: +1 health, +3 damage.", "dmg": 5,
			"apply": func(p): p.add_viking_helmet()},
		{"id": "capitan_helmet", "name": "Captain Helmet", "cost": 22, "max": 1, "unlock": "capitan_helmet", "icon": icon_capitan_helmet,
			"desc": "+10 max health, +5 damage; frenzy (speed + damage) when below 50% health. Unlocked by defeating a Bigminion Capitán.", "life": 10, "dmg": 5,
			"apply": func(p): p.add_capitan_helmet()},
		{"id": "grancapitan_helmet", "name": "Grand Captain Helmet", "cost": 30, "max": 1, "unlock": "grancapitan_helmet", "icon": icon_grancapitan_helmet,
			"desc": "+15 max health, +10 damage; summons 4 allied Capitanes. Unlocked by defeating the Gran Capitán.", "life": 15, "dmg": 10,
			"apply": func(p): p.add_grancapitan_helmet()},
	]

func _build_ui() -> void:
	# Quitar el panel gris por defecto y poner un fondo oscuro translúcido
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.03, 0.06, 0.62)
	add_child(bg)

	# Título, monedas y ROLL sobre Rectangulo_UI_Para_texto
	_make_text_rect(Vector2(520, 16), Vector2(240, 92), "SHOP", 30)
	_coins_label = _make_text_rect(Vector2(40, 16), Vector2(260, 92), "", 22)
	var rr := _make_button_rect(Vector2(980, 16), Vector2(260, 92), "ROLL", 24, _on_reroll)
	_reroll_button = rr[0]
	_reroll_label = rr[1]

	# 4 tarjetas de ítems
	_cards.clear()
	for i in slots:
		var card = ITEM_CARD.instantiate()
		add_child(card)
		card.scale = Vector2(CARD_SCALE, CARD_SCALE)
		card.position = Vector2(CARD_X0 + i * (CARD_W + CARD_GAP), CARD_Y)
		card.buy_pressed.connect(_on_buy)
		_cards.append(card)

	# Botón continuar (también sobre Rectangulo)
	var cont := _make_button_rect(Vector2(520, 632), Vector2(240, 76), "CONTINUE", 24, _on_continue)
	cont[0].text = ""   # el texto lo pone la etiqueta del rectángulo

# Crea un Control con el sprite Rectangulo de fondo y una etiqueta centrada.
func _make_text_rect(pos: Vector2, size: Vector2, text: String, font_size: int) -> Label:
	var holder := Control.new()
	holder.position = pos
	holder.size = size
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)

	var tex := TextureRect.new()
	tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	tex.texture = RECT_TEX
	tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_SCALE
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(tex)

	var label := Label.new()
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.98, 0.9, 0.72))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(label)
	return label

# Igual que el anterior pero con un botón transparente encima. Devuelve [Button, Label].
func _make_button_rect(pos: Vector2, size: Vector2, text: String, font_size: int, cb: Callable) -> Array:
	var label := _make_text_rect(pos, size, text, font_size)
	var holder := label.get_parent()
	holder.mouse_filter = Control.MOUSE_FILTER_PASS

	var button := Button.new()
	button.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.focus_mode = Control.FOCUS_NONE
	for s in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(s, StyleBoxEmpty.new())
	button.pressed.connect(cb)
	holder.add_child(button)
	return [button, label]

func open(wave: int = 0) -> void:
	if player == null or not is_instance_valid(player):
		var players := get_tree().get_nodes_in_group("player")
		player = players[0] if players.size() > 0 else null
	_roll()
	visible = true
	_refresh()

func _is_available(item: Dictionary) -> bool:
	# Cascos desbloqueables: solo aparecen si el desbloqueo persistente está activo.
	var req := String(item.get("unlock", ""))
	if req != "" and not Game.is_unlocked(req):
		return false
	var max_buys := int(item.get("max", 0))
	if max_buys <= 0:
		return true
	if player == null or not is_instance_valid(player):
		return true
	return player.get_item_count(String(item.get("id", ""))) < max_buys

func _available_pool() -> Array:
	var result := []
	for item in _pool:
		if _is_available(item):
			result.append(item)
	return result

func _roll() -> void:
	var available := _available_pool()
	available.shuffle()
	_current = available.slice(0, min(slots, available.size()))

func _refresh() -> void:
	if not visible:
		return
	if _coins_label != null:
		_coins_label.text = tr("%d coins") % Game.coins
	if _reroll_label != null:
		_reroll_label.text = tr("ROLL (%d)") % reroll_cost
	if _reroll_button != null:
		_reroll_button.disabled = Game.coins < reroll_cost

	for i in _cards.size():
		var item = _current[i] if i < _current.size() else null
		if item == null:
			# Hueco vacío: la carta se compró (se repone solo con ROLL).
			_cards[i].visible = false
			continue
		var affordable: bool = Game.coins >= int(item["cost"]) and _is_available(item)
		_cards[i].visible = true
		_cards[i].setup(item, i, affordable)

func _on_buy(index: int) -> void:
	if index >= _current.size():
		return
	var item = _current[index]
	if item == null or not _is_available(item):
		return
	if Game.spend(int(item["cost"])):
		if player != null and is_instance_valid(player):
			item["apply"].call(player)
			if player.has_method("register_item"):
				player.register_item(item)
		# La carta comprada desaparece de la tienda; deja un hueco vacío.
		# Para conseguir nuevas cartas hay que usar ROLL.
		_current[index] = null
	_refresh()

func _on_reroll() -> void:
	if Game.spend(reroll_cost):
		_roll()
	_refresh()

func _on_continue() -> void:
	visible = false
	continue_pressed.emit()
