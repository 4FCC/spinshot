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
@export var charger_scene: PackedScene
@export var support_scene: PackedScene

@export_group("Jefe")
@export var boss_scene: PackedScene        # Aparece al terminar la última oleada

@export_group("Oleadas")
@export var spawn_radius: float = 650.0   # Distancia a la que aparecen del jugador
@export var wave_duration: float = 60.0   # Segundos que dura cada oleada
@export var total_waves: int = 10         # Tras la última oleada aparece el jefe

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
var _waves: Array = []          # Tabla de oleadas (ver _build_waves)
var _boss: Node = null          # Instancia del jefe (si está vivo)
var _boss_pending: bool = false # Tras la oleada final: tienda y luego jefe

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

	_build_waves()
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
	elif event.is_action_pressed("spawn_boss"):
		# Tecla de depuración: invoca el jefe manualmente para pruebas
		_spawn_boss()

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

	# Siempre se abre la tienda al terminar una oleada. Tras la última oleada,
	# al salir de la tienda comienza el combate contra el jefe (no otra oleada).
	if wave_number >= total_waves:
		_boss_pending = true
		info_label.text = "Compra mejoras y prepárate para el JEFE"
	shop.open()

func _on_shop_continue() -> void:
	if _boss_pending:
		# Al salir de la tienda tras la oleada final, aparece el jefe
		_boss_pending = false
		_spawn_boss()
	else:
		# En el resto de casos, empieza automáticamente la siguiente oleada
		_start_wave()

# =============================================================================
# TABLA DE OLEADAS
# =============================================================================
# Cada oleada define su intervalo de aparición y un "pool" de tipos de enemigo
# con pesos: [escena, peso]. El spawner elige al azar según esos pesos. Para
# modificar o añadir oleadas, edita _build_waves() (ver docs/oleadas.md).
func _build_waves() -> void:
	_waves = [
		{"interval": 0.8, "pool": [[minion_scene, 1]]},
		{"interval": 0.8, "pool": [[minion_scene, 3], [charger_scene, 1]]},
		{"interval": 0.9, "pool": [[minion_scene, 2], [bigminion_scene, 1]]},
		{"interval": 0.9, "pool": [[minion_scene, 2], [charger_scene, 2]]},
		{"interval": 1.0, "pool": [[bigminion_scene, 2], [bulletminion_scene, 1]]},
		{"interval": 0.9, "pool": [[minion_scene, 2], [charger_scene, 2], [support_scene, 1]]},
		{"interval": 1.0, "pool": [[bulletminion_scene, 2], [bigminion_scene, 1], [support_scene, 1]]},
		{"interval": 0.9, "pool": [[charger_scene, 2], [bigminion_scene, 2], [bulletminion_scene, 1]]},
		{"interval": 0.9, "pool": [[minion_scene, 2], [charger_scene, 2], [bulletminion_scene, 1], [bigminion_scene, 1], [support_scene, 1]]},
		{"interval": 0.8, "pool": [[minion_scene, 2], [charger_scene, 2], [bigminion_scene, 2], [bulletminion_scene, 2], [support_scene, 1]]},
	]

func _spawn_interval() -> float:
	var idx := clampi(wave_number - 1, 0, _waves.size() - 1)
	return _waves[idx].get("interval", 1.0)

func _pick_enemy_scene() -> PackedScene:
	"""Elige un tipo de enemigo de la oleada actual por peso (ignora nulos)."""
	var idx := clampi(wave_number - 1, 0, _waves.size() - 1)
	var pool: Array = _waves[idx].get("pool", [])
	var total := 0
	for entry in pool:
		if entry[0] != null:
			total += int(entry[1])
	if total <= 0:
		return minion_scene
	var roll := randi() % total
	for entry in pool:
		if entry[0] == null:
			continue
		roll -= int(entry[1])
		if roll < 0:
			return entry[0]
	return minion_scene

func _spawn_enemy() -> void:
	var scene := _pick_enemy_scene()
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
	# Limpia los minions de la oleada, pero NO al jefe.
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy.is_in_group("boss"):
			continue
		enemy.queue_free()

# =============================================================================
# JEFE
# =============================================================================
func _spawn_boss() -> void:
	if _boss != null and is_instance_valid(_boss):
		return   # ya hay un jefe en juego
	if boss_scene == null:
		_show_victory()   # sin jefe asignado: victoria directa
		return
	if player == null or not is_instance_valid(player):
		player = _find_player()

	var boss = boss_scene.instantiate()
	var host := get_tree().current_scene
	if host == null:
		host = get_parent()
	host.add_child(boss)
	if player != null:
		boss.global_position = player.global_position + Vector2.RIGHT.rotated(randf() * TAU) * 480.0
	if boss.has_signal("died"):
		boss.died.connect(_on_boss_defeated)
	_boss = boss

	wave_active = false
	timer_label.text = ""
	info_label.text = "¡JEFE FINAL!"

func _on_boss_defeated() -> void:
	_boss = null
	_show_victory()

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
		wave_label.text = "Oleada %d / %d" % [wave_number, total_waves]

func _update_timer_label() -> void:
	timer_label.text = "Tiempo: %d s" % ceili(maxf(time_left, 0.0))
