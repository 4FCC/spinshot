extends Panel

# =============================================================================
# SHOP — Tienda entre oleadas
# =============================================================================
# Muestra 4 mejoras comprables con monedas. Cada mejora aplica un efecto sobre
# el jugador. Al terminar, el botón "Continuar" emite la señal para que el
# gestor de oleadas permita empezar la siguiente.

signal continue_pressed

@export var icon_health: Texture2D
@export var icon_damage: Texture2D
@export var icon_speed: Texture2D
@export var icon_firerate: Texture2D

var player: Node2D = null
var _upgrades: Array = []
var _buttons: Array = []
var _coins_label: Label = null

func _ready() -> void:
	visible = false
	_build_ui()
	Game.coins_changed.connect(func(_t): _refresh())

func _build_ui() -> void:
	_upgrades = [
		{"name": "Vida máxima +5", "cost": 5, "icon": icon_health,
			"apply": func(p): p.upgrade_max_health(5)},
		{"name": "Daño de bala +1", "cost": 8, "icon": icon_damage,
			"apply": func(p): p.upgrade_bullet_damage(1)},
		{"name": "Velocidad +40", "cost": 6, "icon": icon_speed,
			"apply": func(p): p.upgrade_speed(40.0)},
		{"name": "Cadencia de disparo +15%", "cost": 7, "icon": icon_firerate,
			"apply": func(p): p.upgrade_fire_rate(0.85)},
	]

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

	for i in _upgrades.size():
		var upg = _upgrades[i]
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 56)
		button.icon = upg["icon"]
		button.text = "  %s   (%d monedas)" % [upg["name"], upg["cost"]]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.expand_icon = true
		button.pressed.connect(_on_buy.bind(i))
		vbox.add_child(button)
		_buttons.append(button)

	vbox.add_child(HSeparator.new())

	var continue_button := Button.new()
	continue_button.text = "Continuar (siguiente oleada)"
	continue_button.custom_minimum_size = Vector2(0, 48)
	continue_button.pressed.connect(_on_continue)
	vbox.add_child(continue_button)

func open() -> void:
	if player == null or not is_instance_valid(player):
		var players := get_tree().get_nodes_in_group("player")
		player = players[0] if players.size() > 0 else null
	visible = true
	_refresh()

func _refresh() -> void:
	if _coins_label != null:
		_coins_label.text = "Monedas: %d" % Game.coins
	for i in _buttons.size():
		_buttons[i].disabled = Game.coins < int(_upgrades[i]["cost"])

func _on_buy(index: int) -> void:
	var upg = _upgrades[index]
	if Game.spend(int(upg["cost"])):
		if player != null and is_instance_valid(player):
			upg["apply"].call(player)
	_refresh()

func _on_continue() -> void:
	visible = false
	continue_pressed.emit()
