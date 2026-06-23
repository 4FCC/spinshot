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

@export var slots: int = 4          # Cuántas tarjetas se muestran a la vez
@export var reroll_cost: int = 3    # Coste de la tirada (ROLL)

const ITEM_CARD := preload("res://Scenes/ItemCard.tscn")
const RECT_TEX := preload("res://UI assets/Rectangulo_UI_Para_texto.png")
const COIN_TEX := preload("res://Items assets/COIN_SPRITE.png")

# Disposición de las 4 tarjetas (espacio base 1280x720)
const CARD_SCALE := 0.66
const CARD_W := 400.0 * CARD_SCALE   # ancho mostrado de cada tarjeta
const CARD_GAP := 32.0
const CARD_X0 := 56.0
const CARD_Y := 150.0

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

func _build_pool() -> void:
	# "max" = compras máximas (0 = ilimitado). "dmg"/"life" = stats que muestra la tarjeta.
	_pool = [
		{"id": "health5", "name": "Vida máxima +5", "cost": 5, "max": 0, "icon": icon_health,
			"desc": "Aumenta la vida máxima en 5 y cura esa cantidad.", "life": 5,
			"apply": func(p): p.upgrade_max_health(5)},
		{"id": "health10", "name": "Vida máxima +10", "cost": 9, "max": 0, "icon": icon_extra1,
			"desc": "Aumenta la vida máxima en 10 y cura esa cantidad.", "life": 10,
			"apply": func(p): p.upgrade_max_health(10)},
		{"id": "dmg1", "name": "Daño de bala +1", "cost": 8, "max": 0, "icon": icon_damage,
			"desc": "+1 de daño a cada Spin-Bullet.", "dmg": 1,
			"apply": func(p): p.upgrade_bullet_damage(1)},
		{"id": "dmg2", "name": "Daño de bala +2", "cost": 14, "max": 0, "icon": icon_extra2,
			"desc": "+2 de daño a cada Spin-Bullet.", "dmg": 2,
			"apply": func(p): p.upgrade_bullet_damage(2)},
		{"id": "speed", "name": "Velocidad +40", "cost": 6, "max": 0, "icon": icon_speed,
			"desc": "+40 de velocidad de movimiento.",
			"apply": func(p): p.upgrade_speed(40.0)},
		{"id": "firerate", "name": "Cadencia +15%", "cost": 7, "max": 0, "icon": icon_firerate,
			"desc": "Reduce el tiempo entre disparos un 15%.",
			"apply": func(p): p.upgrade_fire_rate(0.85)},
		{"id": "coinheal", "name": "Robo de vida", "cost": 10, "max": 3, "icon": icon_coinheal,
			"desc": "25% por nivel de curar 1-3 al recoger una moneda. Máx 3.",
			"apply": func(p): p.add_coin_heal()},
		{"id": "bounce", "name": "Rebote ofensivo", "cost": 15, "max": 3, "icon": icon_bounce,
			"desc": "Cada SpinShot genera una nueva al impactar. Máx 3.",
			"apply": func(p): p.add_bounce()},
		{"id": "split", "name": "División de proyectil", "cost": 18, "max": 1, "icon": icon_split,
			"desc": "La SpinShot se divide en dos a media trayectoria. Única.",
			"apply": func(p): p.enable_split()},
		{"id": "lethal", "name": "Giro letal", "cost": 6, "max": 0, "icon": icon_lethal,
			"desc": "+1% por compra de matar al enemigo girando. Sin límite.",
			"apply": func(p): p.add_lethal()},
		{"id": "autododge", "name": "Esquiva automática", "cost": 12, "max": 3, "icon": icon_autododge,
			"desc": "25% por nivel de esquivar al recibir daño. Máx 3.",
			"apply": func(p): p.add_autododge()},
	]

func _build_ui() -> void:
	# Quitar el panel gris por defecto y poner un fondo oscuro translúcido
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.03, 0.06, 0.62)
	add_child(bg)

	# Título, monedas y ROLL sobre Rectangulo_UI_Para_texto
	_make_text_rect(Vector2(520, 16), Vector2(240, 92), "TIENDA", 30)
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
	var cont := _make_button_rect(Vector2(520, 632), Vector2(240, 76), "CONTINUAR", 24, _on_continue)
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

func _prune_and_refill() -> void:
	var kept := []
	for it in _current:
		if _is_available(it):
			kept.append(it)
	var extra := []
	for it in _available_pool():
		if not kept.has(it):
			extra.append(it)
	extra.shuffle()
	while kept.size() < slots and extra.size() > 0:
		kept.append(extra.pop_back())
	_current = kept

func _refresh() -> void:
	if not visible:
		return
	if _coins_label != null:
		_coins_label.text = "%d monedas" % Game.coins
	if _reroll_label != null:
		_reroll_label.text = "ROLL (%d)" % reroll_cost
	if _reroll_button != null:
		_reroll_button.disabled = Game.coins < reroll_cost

	for i in _cards.size():
		if i < _current.size():
			var item = _current[i]
			var affordable: bool = Game.coins >= int(item["cost"]) and _is_available(item)
			_cards[i].visible = true
			_cards[i].setup(item, i, affordable)
		else:
			_cards[i].visible = false

func _on_buy(index: int) -> void:
	if index >= _current.size():
		return
	var item = _current[index]
	if not _is_available(item):
		return
	if Game.spend(int(item["cost"])):
		if player != null and is_instance_valid(player):
			item["apply"].call(player)
			if player.has_method("register_item"):
				player.register_item(item)
	_prune_and_refill()
	_refresh()

func _on_reroll() -> void:
	if Game.spend(reroll_cost):
		_roll()
	_refresh()

func _on_continue() -> void:
	visible = false
	continue_pressed.emit()
