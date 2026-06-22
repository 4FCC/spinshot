extends Panel

# =============================================================================
# SHOP — Tienda entre oleadas
# =============================================================================
# Muestra una selección aleatoria de mejoras de un pool. Un botón de "tirada de
# dados" (reroll) cambia las opciones por monedas. Respeta los límites de compra
# de cada ítem: los de compra única o que alcanzan su nivel máximo dejan de
# aparecer (ni al abrir la tienda ni con el reroll).

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

@export var slots: int = 4          # Cuántas opciones se muestran a la vez
@export var reroll_cost: int = 3    # Coste de la tirada de dados

var player: Node2D = null
var _pool: Array = []          # Todas las mejoras posibles
var _current: Array = []       # Mejoras mostradas ahora
var _option_buttons: Array = []
var _coins_label: Label = null
var _options_box: VBoxContainer = null
var _reroll_button: Button = null

func _ready() -> void:
	visible = false
	_build_pool()
	_build_ui()
	Game.coins_changed.connect(func(_t): _refresh())

func _build_pool() -> void:
	# "max" = número máximo de compras (0 = ilimitado).
	_pool = [
		{"id": "health5", "name": "Vida máxima +5", "cost": 5, "max": 0, "icon": icon_health,
			"desc": "Aumenta la vida máxima en 5 y cura esa cantidad.",
			"apply": func(p): p.upgrade_max_health(5)},
		{"id": "health10", "name": "Vida máxima +10", "cost": 9, "max": 0, "icon": icon_extra1,
			"desc": "Aumenta la vida máxima en 10 y cura esa cantidad.",
			"apply": func(p): p.upgrade_max_health(10)},
		{"id": "dmg1", "name": "Daño de bala +1", "cost": 8, "max": 0, "icon": icon_damage,
			"desc": "+1 de daño a cada Spin-Bullet.",
			"apply": func(p): p.upgrade_bullet_damage(1)},
		{"id": "dmg2", "name": "Daño de bala +2", "cost": 14, "max": 0, "icon": icon_extra2,
			"desc": "+2 de daño a cada Spin-Bullet.",
			"apply": func(p): p.upgrade_bullet_damage(2)},
		{"id": "speed", "name": "Velocidad +40", "cost": 6, "max": 0, "icon": icon_speed,
			"desc": "+40 de velocidad de movimiento.",
			"apply": func(p): p.upgrade_speed(40.0)},
		{"id": "firerate", "name": "Cadencia de disparo +15%", "cost": 7, "max": 0, "icon": icon_firerate,
			"desc": "Reduce el tiempo entre disparos un 15%.",
			"apply": func(p): p.upgrade_fire_rate(0.85)},
		# --- Ítems con habilidad especial ---
		{"id": "coinheal", "name": "Robo de vida al recoger moneda", "cost": 10, "max": 3, "icon": icon_coinheal,
			"desc": "25% por nivel de curar 1-3 al recoger una moneda. Máx 3 niveles (75%).",
			"apply": func(p): p.add_coin_heal()},
		{"id": "bounce", "name": "Rebote ofensivo: +1 SpinShot", "cost": 15, "max": 3, "icon": icon_bounce,
			"desc": "Cada SpinShot genera una nueva al impactar a un enemigo. Máx 3.",
			"apply": func(p): p.add_bounce()},
		{"id": "split", "name": "División de proyectil (única)", "cost": 18, "max": 1, "icon": icon_split,
			"desc": "La SpinShot se divide en dos a media trayectoria. Compra única.",
			"apply": func(p): p.enable_split()},
		{"id": "lethal", "name": "Giro letal: +1% muerte al girar", "cost": 6, "max": 0, "icon": icon_lethal,
			"desc": "+1% por compra de matar al enemigo haciéndolo girar. Sin límite.",
			"apply": func(p): p.add_lethal()},
		{"id": "autododge", "name": "Esquiva automática +25%", "cost": 12, "max": 3, "icon": icon_autododge,
			"desc": "25% por nivel de esquivar automáticamente al recibir daño. Máx 3 (75%).",
			"apply": func(p): p.add_autododge()},
	]

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "TIENDA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	vbox.add_child(title)

	_coins_label = Label.new()
	_coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_coins_label)

	vbox.add_child(HSeparator.new())

	# Contenedor donde se generan las opciones (cambian con cada tirada)
	_options_box = VBoxContainer.new()
	_options_box.add_theme_constant_override("separation", 8)
	vbox.add_child(_options_box)

	vbox.add_child(HSeparator.new())

	_reroll_button = Button.new()
	_reroll_button.custom_minimum_size = Vector2(0, 44)
	_reroll_button.pressed.connect(_on_reroll)
	vbox.add_child(_reroll_button)

	var continue_button := Button.new()
	continue_button.text = "Continuar"
	continue_button.custom_minimum_size = Vector2(0, 48)
	continue_button.pressed.connect(_on_continue)
	vbox.add_child(continue_button)

func open() -> void:
	if player == null or not is_instance_valid(player):
		var players := get_tree().get_nodes_in_group("player")
		player = players[0] if players.size() > 0 else null
	_roll()        # nueva selección al abrir
	visible = true
	_refresh()

func _is_available(item: Dictionary) -> bool:
	"""Un ítem está disponible si no ha alcanzado su límite de compras."""
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
	"""Tirada de dados: elige 'slots' mejoras DISPONIBLES y distintas del pool."""
	var available := _available_pool()
	available.shuffle()
	_current = available.slice(0, min(slots, available.size()))
	_populate_options()

func _prune_and_refill() -> void:
	"""Quita de la vista los ítems que ya no estén disponibles (compra única o
	nivel máximo) y rellena los huecos con otras opciones disponibles."""
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
	_populate_options()

func _populate_options() -> void:
	for child in _options_box.get_children():
		child.queue_free()
	_option_buttons.clear()

	for i in _current.size():
		var upg = _current[i]
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 56)
		button.icon = upg["icon"]
		button.text = "  %s   (%d monedas)" % [upg["name"], upg["cost"]]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.expand_icon = true
		button.tooltip_text = String(upg.get("desc", ""))
		button.pressed.connect(_on_buy.bind(i))
		_options_box.add_child(button)
		_option_buttons.append(button)

func _refresh() -> void:
	if _coins_label != null:
		_coins_label.text = "Monedas: %d" % Game.coins
	for i in _option_buttons.size():
		if i >= _current.size():
			continue
		var item = _current[i]
		_option_buttons[i].disabled = Game.coins < int(item["cost"]) or not _is_available(item)
	if _reroll_button != null:
		_reroll_button.text = "Tirar dado: nuevas opciones (%d monedas)" % reroll_cost
		_reroll_button.disabled = Game.coins < reroll_cost

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
	# Tras comprar, retira los ítems que se hayan agotado y rellena
	_prune_and_refill()
	_refresh()

func _on_reroll() -> void:
	if Game.spend(reroll_cost):
		_roll()
	_refresh()

func _on_continue() -> void:
	visible = false
	continue_pressed.emit()
