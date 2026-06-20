extends Node

# =============================================================================
# GAME MODE — Bucle de juego reutilizable (oleadas, tienda y pantallas)
# =============================================================================
# Componente que se instancia en cualquier escena con un jugador (Main, DEV-ROOM).
# Gestiona:
#   - Oleadas por etapas (Minions / BigMinions / BulletMinions), 60s cada una.
#   - Tienda entre oleadas (con tirada de dados).
#   - Pantallas de inicio, victoria y muerte.
# No construye el suelo ni coloca al jugador: de eso se encargan las escenas.

@export_group("Escenas de enemigos")
@export var minion_scene: PackedScene
@export var bigminion_scene: PackedScene
@export var bulletminion_scene: PackedScene

@export_group("Oleadas")
@export var spawn_radius: float = 650.0   # Distancia a la que aparecen del jugador
@export var wave_duration: float = 60.0   # Segundos que dura cada oleada
@export var total_waves: int = 3          # Al completar esta oleada -> victoria

@onready var ui: CanvasLayer = $UI
@onready var coins_label: Label = $UI/CoinsLabel
@onready var wave_label: Label = $UI/WaveLabel
@onready var timer_label: Label = $UI/TimerLabel
@onready var info_label: Label = $UI/InfoLabel
@onready var shop = $UI/Shop

var player: Node2D = null
var wave_number: int = 0
var wave_active: bool = false
var time_left: float = 0.0
var _spawn_accum: float = 0.0

# Pantallas
var _start_screen: Control = null
var _victory_screen: Control = null
var _death_screen: Control = null
var _screen_active: bool = false

func _ready() -> void:
	randomize()
	# El GameMode (y su UI) sigue activo aunque el árbol esté en pausa,
	# para que las pantallas y sus botones funcionen.
	process_mode = Node.PROCESS_MODE_ALWAYS

	Game.reset()
	Game.coins_changed.connect(_on_coins_changed)
	_on_coins_changed(Game.coins)

	shop.continue_pressed.connect(_on_shop_continue)
	shop.visible = false

	_build_screens()
	_update_wave_label()
	timer_label.text = ""
	info_label.text = ""

	call_deferred("_connect_player")
	_show_start()

func _connect_player() -> void:
	player = _find_player()
	if player != null and player.has_signal("died"):
		if not player.died.is_connected(_on_player_died):
			player.died.connect(_on_player_died)

func _find_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	return players[0] if players.size() > 0 else null

func _process(delta: float) -> void:
	if _screen_active or get_tree().paused or not wave_active:
		return

	# Cuenta atrás de la oleada
	time_left -= delta
	_update_timer_label()
	if time_left <= 0.0:
		_end_wave()
		return

	_spawn_accum -= delta
	if _spawn_accum <= 0.0:
		_spawn_accum = _spawn_interval()
		_spawn_enemy()

func _unhandled_input(event: InputEvent) -> void:
	if _screen_active:
		return
	if event.is_action_pressed("start_wave") and not wave_active and not shop.visible:
		_start_wave()
	elif event.is_action_pressed("end_wave") and wave_active:
		_end_wave()

# =============================================================================
# OLEADAS
# =============================================================================
func _start_wave() -> void:
	wave_number += 1
	wave_active = true
	time_left = wave_duration
	_spawn_accum = 0.0
	_update_wave_label()
	_update_timer_label()
	info_label.text = "Oleada %d en curso — pulsa M para terminar antes" % wave_number

func _end_wave() -> void:
	wave_active = false
	time_left = 0.0
	timer_label.text = ""
	info_label.text = ""
	_clear_enemies()

	# Tras la última oleada: victoria. Si no, tienda.
	if wave_number >= total_waves:
		_show_victory()
	else:
		shop.open()

func _on_shop_continue() -> void:
	# Al cerrar la tienda comienza automáticamente la siguiente oleada
	_start_wave()

func _stage() -> int:
	return clampi(wave_number, 1, 3)

func _spawn_interval() -> float:
	match _stage():
		1:
			return 0.7    # Minions: frecuentes
		2:
			return 1.6    # BigMinions: menos frecuentes
		_:
			return 2.6    # BulletMinions: aún menos frecuentes

func _current_enemy_scene() -> PackedScene:
	match _stage():
		1:
			return minion_scene
		2:
			return bigminion_scene
		_:
			return bulletminion_scene

func _spawn_enemy() -> void:
	var scene := _current_enemy_scene()
	if scene == null:
		return
	if player == null or not is_instance_valid(player):
		player = _find_player()
	if player == null:
		return
	var enemy = scene.instantiate()
	var angle := randf() * TAU
	var host := get_tree().current_scene
	if host == null:
		host = get_parent()
	host.add_child(enemy)
	enemy.global_position = player.global_position + Vector2(cos(angle), sin(angle)) * spawn_radius

func _clear_enemies() -> void:
	for enemy in get_tree().get_nodes_in_group("enemy"):
		enemy.queue_free()

# =============================================================================
# PANTALLAS (inicio / victoria / muerte)
# =============================================================================
func _build_screens() -> void:
	_start_screen = _make_screen("SPINSHOT",
		"Clic der./izq.: disparar Spin-Bullet (dos giros)\nWASD: mover   Espacio: esquivar\nN: iniciar oleada   M: terminarla",
		"JUGAR", _on_start_pressed)
	_victory_screen = _make_screen("¡VICTORIA!",
		"Has superado todas las oleadas.", "Jugar de nuevo", _on_restart_pressed)
	_death_screen = _make_screen("HAS MUERTO",
		"Te han derrotado.", "Reintentar", _on_restart_pressed)

func _make_screen(title_text: String, subtitle_text: String, button_text: String, button_cb: Callable) -> Control:
	var screen := Control.new()
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_STOP

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.05, 0.08, 0.85)
	screen.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 18)
	center.add_child(vbox)

	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	vbox.add_child(title)

	if subtitle_text != "":
		var sub := Label.new()
		sub.text = subtitle_text
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(sub)

	var button := Button.new()
	button.text = button_text
	button.custom_minimum_size = Vector2(240, 54)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(button_cb)
	vbox.add_child(button)

	screen.visible = false
	ui.add_child(screen)
	return screen

func _show_start() -> void:
	_set_screen(_start_screen)

func _show_victory() -> void:
	_set_screen(_victory_screen)

func _show_death() -> void:
	_set_screen(_death_screen)

func _set_screen(screen: Control) -> void:
	_start_screen.visible = screen == _start_screen
	_victory_screen.visible = screen == _victory_screen
	_death_screen.visible = screen == _death_screen
	_screen_active = true
	get_tree().paused = true

func _hide_screens() -> void:
	_start_screen.visible = false
	_victory_screen.visible = false
	_death_screen.visible = false
	_screen_active = false
	get_tree().paused = false

func _on_start_pressed() -> void:
	_hide_screens()
	info_label.text = "Pulsa N para empezar la oleada 1"

func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_player_died() -> void:
	_show_death()

# =============================================================================
# UI
# =============================================================================
func _on_coins_changed(total: int) -> void:
	coins_label.text = "Monedas: %d" % total

func _update_wave_label() -> void:
	if wave_number == 0:
		wave_label.text = "Oleada: -"
	else:
		wave_label.text = "Oleada %d / %d  (Etapa %d)" % [wave_number, total_waves, _stage()]

func _update_timer_label() -> void:
	timer_label.text = "Tiempo: %d s" % ceili(maxf(time_left, 0.0))
