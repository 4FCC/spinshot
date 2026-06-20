extends Panel

# =============================================================================
# SHOP — Tienda entre oleadas
# =============================================================================
# Muestra una selección aleatoria de mejoras de un pool. Un botón de "tirada de
# dados" (reroll) cambia las opciones disponibles por monedas. Al terminar, el
# botón "Continuar" emite la señal para empezar la siguiente oleada.

signal continue_pressed

@export var icon_health: Texture2D
@export var icon_damage: Texture2D
@export var icon_speed: Texture2D
@export var icon_firerate: Texture2D
@export var icon_extra1: Texture2D
@export var icon_extra2: Texture2D

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
	_pool = [
		{"name": "Vida máxima +5", "cost": 5, "icon": icon_health,
			"apply": func(p): p.upgrade_max_health(5)},
		{"name": "Vida máxima +10", "cost": 9, "icon": icon_extra1,
			"apply": func(p): p.upgrade_max_health(10)},
		{"name": "Daño de bala +1", "cost": 8, "icon": icon_damage,
			"apply": func(p): p.upgrade_bullet_damage(1)},
		{"name": "Daño de bala +2", "cost": 14, "icon": icon_extra2,
			"apply": func(p): p.upgrade_bullet_damage(2)},
		{"name": "Velocidad +40", "cost": 6, "icon": icon_speed,
			"apply": func(p): p.upgrade_speed(40.0)},
		{"name": "Cadencia de disparo +15%", "cost": 7, "icon": icon_firerate,
			"apply": func(p): p.upgrade_fire_rate(0.85)},
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
	continue_button.text = "Continuar (siguiente oleada)"
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

func _roll() -> void:
	"""Tirada de dados: elige 'slots' mejoras aleatorias distintas del pool."""
	var available := _pool.duplicate()
	available.shuffle()
	_current = available.slice(0, min(slots, available.size()))
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
		button.pressed.connect(_on_buy.bind(i))
		_options_box.add_child(button)
		_option_buttons.append(button)

func _refresh() -> void:
	if _coins_label != null:
		_coins_label.text = "Monedas: %d" % Game.coins
	for i in _option_buttons.size():
		_option_buttons[i].disabled = Game.coins < int(_current[i]["cost"])
	if _reroll_button != null:
		_reroll_button.text = "Tirar dado: nuevas opciones (%d monedas)" % reroll_cost
		_reroll_button.disabled = Game.coins < reroll_cost

func _on_buy(index: int) -> void:
	if index >= _current.size():
		return
	var upg = _current[index]
	if Game.spend(int(upg["cost"])):
		if player != null and is_instance_valid(player):
			upg["apply"].call(player)
	_refresh()

func _on_reroll() -> void:
	if Game.spend(reroll_cost):
		_roll()
	_refresh()

func _on_continue() -> void:
	visible = false
	continue_pressed.emit()
